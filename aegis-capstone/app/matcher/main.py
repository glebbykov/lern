"""
matcher — Phase 1 skeleton.
Сравнивает входящие NormalizedTxn с ожидаемыми (по external_ref + amount).
Сейчас — заглушка POST /v1/match, всегда возвращает matched=True.
"""
import os
import time
import uuid
from typing import Literal

from fastapi import FastAPI, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

SERVICE_NAME = os.environ.get("SERVICE_NAME", "matcher")
VERSION = os.environ.get("VERSION", "0.1.0")

app = FastAPI(title=SERVICE_NAME, version=VERSION)

REQ_COUNT = Counter(
    "aegis_requests_total",
    "Total HTTP requests",
    ["service", "method", "path", "status"],
)
REQ_LATENCY = Histogram(
    "aegis_request_duration_seconds",
    "Request latency in seconds",
    ["service", "method", "path"],
)
MATCH_RESULTS = Counter(
    "aegis_match_results_total",
    "Matcher decisions: matched | discrepancy (stub).",
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
def ready():
    # Phase 2: проверка коннекта к Redis (hot lookup), etcd (leader election), Kafka, PG.
    return {"ready": True, "deps": {"redis": "skipped", "etcd": "skipped", "kafka": "skipped", "postgres": "skipped"}}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


# ---------------------------------------------------------------------------
# Domain endpoints (Phase 2: реальный matching через Redis ZRANGE expected_until)
# ---------------------------------------------------------------------------

class MatchRequest(BaseModel):
    tenant_id: str
    external_ref: str
    amount_minor: int = Field(..., ge=1)
    currency: str = Field(..., min_length=3, max_length=3)


class MatchResponse(BaseModel):
    match_id: str
    result: Literal["matched", "discrepancy"]
    reason: str


@app.post("/v1/match", response_model=MatchResponse, status_code=200)
def match(req: MatchRequest):
    """Stub: всегда возвращает matched. Phase 2: реальный lookup expected в Redis."""
    MATCH_RESULTS.labels(SERVICE_NAME, "matched").inc()
    return MatchResponse(
        match_id=f"mat_{uuid.uuid4().hex[:16]}",
        result="matched",
        reason="stub: deterministic match, no real lookup",
    )
