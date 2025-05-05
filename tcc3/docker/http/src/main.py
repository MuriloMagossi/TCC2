from fastapi import FastAPI, Response
from prometheus_client import Counter, generate_latest
import structlog

# Configurar logging
logger = structlog.get_logger()

# Configurar métricas
request_counter = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint'])

app = FastAPI()

@app.get("/")
async def root():
    request_counter.labels(method='GET', endpoint='/').inc()
    logger.info("root_endpoint_called")
    return {"message": "Hello from HTTP service"}

@app.get("/health")
async def health():
    request_counter.labels(method='GET', endpoint='/health').inc()
    logger.info("health_check_called")
    return {"status": "healthy"}

@app.get("/metrics")
async def metrics():
    request_counter.labels(method='GET', endpoint='/metrics').inc()
    return Response(generate_latest(), media_type="text/plain") 