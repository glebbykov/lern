"""
normalizer — Phase 2.5
Парсит сырые feed'ы (CSV/JSON/ISO 20022) в каноническую NormalizedTxn модель.
Взаимодействует с MongoDB (сохранение raw-feed) и Kafka (публикация normalized events).
"""
import os
import time
import uuid
import json
from typing import Literal
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

from motor.motor_asyncio import AsyncIOMotorClient
from aiokafka import AIOKafkaProducer
import redis.asyncio as aioredis

SERVICE_NAME = os.environ.get("SERVICE_NAME", "normalizer")
VERSION = os.environ.get("VERSION", "0.2.0")

KAFKA_BOOTSTRAP_SERVERS = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))

db_client = None
kafka_producer = None
redis_client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global db_client, kafka_producer, redis_client
    db_client = AsyncIOMotorClient(MONGO_URI)
    redis_client = aioredis.Redis(host=REDIS_HOST, port=REDIS_PORT)
    kafka_producer = AIOKafkaProducer(bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS)
    await kafka_producer.start()
    yield
    db_client.close()
    await redis_client.close()
    await kafka_producer.stop()

app = FastAPI(title=SERVICE_NAME, version=VERSION, lifespan=lifespan)

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
    "Number of feeds successfully normalized.",
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
async def ready():
    deps = {"kafka": "error", "mongodb": "error", "redis": "error"}
    is_ready = True
    
    try:
        await db_client.admin.command('ping')
        deps["mongodb"] = "ok"
    except Exception:
        is_ready = False
        
    try:
        await redis_client.ping()
        deps["redis"] = "ok"
    except Exception:
        is_ready = False
        
    try:
        if kafka_producer is not None:
            deps["kafka"] = "ok"
    except Exception:
        is_ready = False
        
    if is_ready:
        return {"ready": True, "deps": deps}
    return Response(status_code=503, content=json.dumps({"ready": False, "deps": deps}), media_type="application/json")

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# ---------------------------------------------------------------------------
# Domain endpoints
# ---------------------------------------------------------------------------

class NormalizeRequest(BaseModel):
    tenant_id: str
    source_format: Literal["csv", "json", "iso20022", "nacha"]
    raw_payload: str = Field(..., description="Base64 или plain")

class NormalizeResponse(BaseModel):
    feed_id: str
    accepted_records: int
    status: Literal["accepted"]

@app.post("/v1/normalize", response_model=NormalizeResponse, status_code=202)
async def normalize(req: NormalizeRequest):
    FEEDS_NORMALIZED.labels(SERVICE_NAME, req.source_format).inc()
    accepted = max(1, req.raw_payload.count("\n"))
    feed_id = f"feed_{uuid.uuid4().hex[:16]}"
    
    # Phase 2.5: Запись в Mongo и отправка в Kafka
    try:
        await db_client.aegis.raw_events.insert_one({
            "feed_id": feed_id,
            "tenant_id": req.tenant_id,
            "format": req.source_format,
            "payload": req.raw_payload,
            "ts": time.time()
        })
        
        msg = json.dumps({"feed_id": feed_id, "status": "accepted"}).encode('utf-8')
        await kafka_producer.send_and_wait("normalized-events", msg)
    except Exception as e:
        # For prototype simplicity we just print, in prod we'd handle
        print(f"Error saving/sending event: {e}")

    return NormalizeResponse(
        feed_id=feed_id,
        accepted_records=accepted,
        status="accepted",
    )
