"""
ledger-api — Phase 1 skeleton.
Пишет двойную запись в PostgreSQL (потом). Сейчас — заглушка с /health, /metrics
и единственным domain-endpoint'ом POST /v1/entries, возвращающим stub-id.
"""
import os
import time
import uuid
from typing import Literal

from fastapi import FastAPI, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

SERVICE_NAME = os.environ.get("SERVICE_NAME", "ledger-api")
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
ENTRIES_CREATED = Counter(
    "aegis_ledger_entries_created_total",
    "Number of ledger entries accepted (stub).",
    ["service"],
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
    # Phase 2: проверка коннекта к PG (10.100.0.11:5432) и Kafka (10.100.0.12:9092).
    return {"ready": True, "deps": {"postgres": "skipped", "kafka": "skipped"}}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


# ---------------------------------------------------------------------------
# Domain endpoints (заглушки — Phase 2 заменит на реальный двойной журнал в PG)
# ---------------------------------------------------------------------------

class LedgerEntryRequest(BaseModel):
    tenant_id: str
    debit_account: str
    credit_account: str
    amount_minor: int = Field(..., ge=1, description="Сумма в минорных единицах (центы и т.п.)")
    currency: str = Field(..., min_length=3, max_length=3)
    external_ref: str


class LedgerEntryResponse(BaseModel):
    entry_id: str
    status: Literal["accepted"]


@app.post("/v1/entries", response_model=LedgerEntryResponse, status_code=202)
def create_entry(req: LedgerEntryRequest):
    """Stub: принимает entry, возвращает фейковый id. Phase 2: real double-entry в PG."""
    ENTRIES_CREATED.labels(SERVICE_NAME).inc()
    return LedgerEntryResponse(entry_id=f"led_{uuid.uuid4().hex[:16]}", status="accepted")
