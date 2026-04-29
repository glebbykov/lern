"""
matcher — Phase 2.
Простейший reconciliation: ожидаемые транзакции лежат в Redis под ключом
expected:{tenant_id}:{external_ref} → JSON {amount_minor, currency, expires_at}.
POST /v1/match сравнивает входящую с этой записью.

Дополнительный POST /v1/expected — записать "ожидание" (для smoke-теста).

Phase 3: REDIS_HOST → overlay-IP реального az-db (10.100.0.11).
"""
import json
import os
import time
import uuid
from contextlib import asynccontextmanager
from typing import Literal

import redis.asyncio as redis
from fastapi import FastAPI, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

SERVICE_NAME = os.environ.get("SERVICE_NAME", "matcher")
VERSION = os.environ.get("VERSION", "0.2.0")
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.redis = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
    try:
        yield
    finally:
        await app.state.redis.aclose()


app = FastAPI(title=SERVICE_NAME, version=VERSION, lifespan=lifespan)

REQ_COUNT = Counter(
    "aegis_requests_total", "Total HTTP requests",
    ["service", "method", "path", "status"],
)
REQ_LATENCY = Histogram(
    "aegis_request_duration_seconds", "Request latency in seconds",
    ["service", "method", "path"],
)
MATCH_RESULTS = Counter(
    "aegis_match_results_total",
    "Matcher decisions: matched | discrepancy | not_found.",
    ["service", "result"],
)


@app.middleware("http")
async def metrics_mw(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    elapsed = time.perf_counter() - start
    path = request.url.path
    REQ_COUNT.labels(SERVICE_NAME, request.method, path, response.status_code).inc()
    REQ_LATENCY.labels(SERVICE_NAME, request.method, path).observe(elapsed)
    return response


@app.get("/health")
def health():
    return {"status": "ok", "service": SERVICE_NAME, "version": VERSION}


@app.get("/ready")
async def ready():
    deps = {}
    try:
        pong = await app.state.redis.ping()
        deps["redis"] = "ok" if pong else "no-pong"
        ok = bool(pong)
    except Exception as e:
        deps["redis"] = f"error: {type(e).__name__}"
        ok = False
    if not ok:
        return Response(
            content=json.dumps({"ready": False, "deps": deps}),
            status_code=503,
            media_type="application/json",
        )
    return {"ready": True, "deps": deps}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


# ---------------------------------------------------------------------------
# Domain
# ---------------------------------------------------------------------------

def _key(tenant_id: str, external_ref: str) -> str:
    return f"expected:{tenant_id}:{external_ref}"


class ExpectedRequest(BaseModel):
    tenant_id: str
    external_ref: str
    amount_minor: int = Field(..., ge=1)
    currency: str = Field(..., min_length=3, max_length=3)
    ttl_seconds: int = Field(3600, ge=1, le=86400 * 7)


@app.post("/v1/expected", status_code=201)
async def add_expected(req: ExpectedRequest):
    """Регистрирует ожидаемую транзакцию (TTL по дефолту 1ч). Используется upstream'ом."""
    payload = {"amount_minor": req.amount_minor, "currency": req.currency.upper()}
    await app.state.redis.set(_key(req.tenant_id, req.external_ref), json.dumps(payload), ex=req.ttl_seconds)
    return {"status": "registered", "ttl_seconds": req.ttl_seconds}


class MatchRequest(BaseModel):
    tenant_id: str
    external_ref: str
    amount_minor: int = Field(..., ge=1)
    currency: str = Field(..., min_length=3, max_length=3)


class MatchResponse(BaseModel):
    match_id: str
    result: Literal["matched", "discrepancy", "not_found"]
    reason: str


@app.post("/v1/match", response_model=MatchResponse)
async def match(req: MatchRequest):
    raw = await app.state.redis.get(_key(req.tenant_id, req.external_ref))
    match_id = f"mat_{uuid.uuid4().hex[:16]}"

    if raw is None:
        MATCH_RESULTS.labels(SERVICE_NAME, "not_found").inc()
        return MatchResponse(match_id=match_id, result="not_found", reason="no expected record for ref")

    expected = json.loads(raw)
    if expected["amount_minor"] != req.amount_minor or expected["currency"] != req.currency.upper():
        MATCH_RESULTS.labels(SERVICE_NAME, "discrepancy").inc()
        return MatchResponse(
            match_id=match_id,
            result="discrepancy",
            reason=f"expected {expected['amount_minor']} {expected['currency']}, got {req.amount_minor} {req.currency.upper()}",
        )

    # Match найден — снимаем expected (one-shot).
    await app.state.redis.delete(_key(req.tenant_id, req.external_ref))
    MATCH_RESULTS.labels(SERVICE_NAME, "matched").inc()
    return MatchResponse(match_id=match_id, result="matched", reason="amount + currency + ref equal to expected")
