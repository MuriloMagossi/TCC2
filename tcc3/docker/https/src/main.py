from fastapi import FastAPI, Response
from prometheus_client import Counter, generate_latest
import structlog
import ssl

# Configurar logging
logger = structlog.get_logger()

# Configurar métricas
request_counter = Counter('https_requests_total', 'Total HTTPS requests', ['method', 'endpoint'])

app = FastAPI()

@app.get("/")
async def root():
    request_counter.labels(method='GET', endpoint='/').inc()
    logger.info("root_endpoint_called")
    return {"message": "Hello from HTTPS service"}

@app.get("/health")
async def health():
    request_counter.labels(method='GET', endpoint='/health').inc()
    logger.info("health_check_called")
    return {"status": "healthy"}

@app.get("/metrics")
async def metrics():
    request_counter.labels(method='GET', endpoint='/metrics').inc()
    return Response(generate_latest(), media_type="text/plain")

if __name__ == "__main__":
    logger.info("service_starting", service="https")
    
    # Configuração SSL
    ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ssl_context.load_cert_chain(
        certfile="/app/certs/cert.pem",
        keyfile="/app/certs/key.pem"
    )
    
    # Iniciar servidor com SSL
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8443,
        ssl_keyfile="/app/certs/key.pem",
        ssl_certfile="/app/certs/cert.pem"
    ) 