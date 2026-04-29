"""
normalizer — Phase 1 skeleton.
Парсит сырые feed'ы (CSV/JSON/ISO 20022) в каноническую NormalizedTxn модель.
Сейчас — заглушка POST /v1/normalize, считающая accepted-feed'ы.
"""
import os
import time
import uuid
from typing import Literal

from fastapi import FastAPI, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

SERVICE_NAME = os.environ.get("SERVICE_NAME", "normalizer")
VERSION = os.environ.get("VERSION", "0.2.0")

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
FEEDS_NORMALIZED = Counter(
    "aegis_feeds_normalized_total",
    "Number of feeds successfully normalized (stub).",
    ["service", "source_format"],
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
    # Phase 2.5: подключить Kafka (consumer raw-feeds), MongoDB (RawEvent storage),
    # Redis (FX-rates cache). Сейчас — без external deps (parser-only, in-memory).
    return {"ready": True, "deps": {"kafka": "phase-2.5", "mongodb": "phase-2.5", "redis": "phase-2.5"}}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


# ---------------------------------------------------------------------------
# Domain endpoints (Phase 2: реальный парсинг ISO 20022 / NACHA / CSV)
# ---------------------------------------------------------------------------

class NormalizeRequest(BaseModel):
    tenant_id: str
    source_format: Literal["csv", "json", "iso20022", "nacha"]
    raw_payload: str = Field(..., description="Base64 или plain — заглушка не парсит")


class NormalizeResponse(BaseModel):
    feed_id: str
    accepted_records: int
    status: Literal["accepted"]


@app.post("/v1/normalize", response_model=NormalizeResponse, status_code=202)
def normalize(req: NormalizeRequest):
    """Stub: считает «принятые» записи как количество строк в payload, ничего не парсит."""
    FEEDS_NORMALIZED.labels(SERVICE_NAME, req.source_format).inc()
    accepted = max(1, req.raw_payload.count("\n"))
    return NormalizeResponse(
        feed_id=f"feed_{uuid.uuid4().hex[:16]}",
        accepted_records=accepted,
        status="accepted",
    )
