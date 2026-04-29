"""
ledger-api — Phase 2.
Реальный INSERT в PostgreSQL: таблица journal_entries (immutable journal).
Идемпотентность по (tenant_id, external_ref).

Phase 3: POSTGRES_HOST переключится на overlay IP `10.100.0.11`.
"""
import os
import time
import uuid
from contextlib import asynccontextmanager
from typing import Literal

import asyncpg
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

SERVICE_NAME = os.environ.get("SERVICE_NAME", "ledger-api")
VERSION = os.environ.get("VERSION", "0.2.0")

PG_DSN = (
    f"postgres://{os.environ['POSTGRES_USER']}:{os.environ['POSTGRES_PASSWORD']}"
    f"@{os.environ['POSTGRES_HOST']}:{os.environ.get('POSTGRES_PORT', '5432')}"
    f"/{os.environ['POSTGRES_DB']}"
)

# Минимальная схема. В реальном ledger'е будут partitioning by month, RLS,
# debit/credit как два row'а с FK на entry_id; здесь — flat-таблица для smoke-теста.
MIGRATIONS = [
    """
    CREATE TABLE IF NOT EXISTS journal_entries (
        entry_id        TEXT PRIMARY KEY,
        tenant_id       TEXT NOT NULL,
        external_ref    TEXT NOT NULL,
        debit_account   TEXT NOT NULL,
        credit_account  TEXT NOT NULL,
        amount_minor    BIGINT NOT NULL CHECK (amount_minor > 0),
        currency        CHAR(3) NOT NULL,
        created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    """,
    """
    CREATE UNIQUE INDEX IF NOT EXISTS journal_entries_tenant_extref_uidx
        ON journal_entries (tenant_id, external_ref);
    """,
]


@asynccontextmanager
async def lifespan(app: FastAPI):
    pool = await asyncpg.create_pool(dsn=PG_DSN, min_size=1, max_size=8)
    async with pool.acquire() as conn:
        for stmt in MIGRATIONS:
            await conn.execute(stmt)
    app.state.pg = pool
    try:
        yield
    finally:
        await pool.close()


app = FastAPI(title=SERVICE_NAME, version=VERSION, lifespan=lifespan)

REQ_COUNT = Counter(
    "aegis_requests_total", "Total HTTP requests",
    ["service", "method", "path", "status"],
)
REQ_LATENCY = Histogram(
    "aegis_request_duration_seconds", "Request latency in seconds",
    ["service", "method", "path"],
)
ENTRIES_CREATED = Counter(
    "aegis_ledger_entries_created_total",
    "Number of ledger entries successfully written.",
    ["service"],
)
ENTRIES_DEDUPED = Counter(
    "aegis_ledger_entries_deduped_total",
    "Idempotent retries (same external_ref) returned existing entry_id.",
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
async def ready():
    deps = {}
    try:
        async with app.state.pg.acquire() as conn:
            await conn.execute("SELECT 1;")
        deps["postgres"] = "ok"
        ok = True
    except Exception as e:
        deps["postgres"] = f"error: {type(e).__name__}"
        ok = False
    if not ok:
        return Response(
            content=f'{{"ready": false, "deps": {deps}}}',
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

class LedgerEntryRequest(BaseModel):
    tenant_id: str
    debit_account: str
    credit_account: str
    amount_minor: int = Field(..., ge=1)
    currency: str = Field(..., min_length=3, max_length=3)
    external_ref: str


class LedgerEntryResponse(BaseModel):
    entry_id: str
    status: Literal["accepted", "duplicate"]


@app.post("/v1/entries", response_model=LedgerEntryResponse, status_code=202)
async def create_entry(req: LedgerEntryRequest):
    entry_id = f"led_{uuid.uuid4().hex[:16]}"
    sql = """
        INSERT INTO journal_entries
            (entry_id, tenant_id, external_ref, debit_account, credit_account, amount_minor, currency)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (tenant_id, external_ref) DO UPDATE
            SET tenant_id = EXCLUDED.tenant_id  -- no-op, нужно чтобы RETURNING сработал
        RETURNING entry_id, (xmax = 0) AS inserted;
    """
    async with app.state.pg.acquire() as conn:
        try:
            row = await conn.fetchrow(
                sql,
                entry_id, req.tenant_id, req.external_ref,
                req.debit_account, req.credit_account, req.amount_minor, req.currency.upper(),
            )
        except asyncpg.exceptions.PostgresError as e:
            raise HTTPException(status_code=500, detail=f"db error: {type(e).__name__}")

    if row["inserted"]:
        ENTRIES_CREATED.labels(SERVICE_NAME).inc()
        return LedgerEntryResponse(entry_id=row["entry_id"], status="accepted")
    else:
        ENTRIES_DEDUPED.labels(SERVICE_NAME).inc()
        return LedgerEntryResponse(entry_id=row["entry_id"], status="duplicate")
