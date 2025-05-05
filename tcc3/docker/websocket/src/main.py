from fastapi import FastAPI, WebSocket, Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import structlog
import uvicorn
import json

# Configuração do logger
logger = structlog.get_logger()

# Criação da aplicação FastAPI
app = FastAPI(title="WebSocket Service")

# Métricas Prometheus
ws_connections_total = Counter('ws_connections_total', 'Total number of WebSocket connections')
ws_messages_total = Counter('ws_messages_total', 'Total number of WebSocket messages', ['direction'])

@app.get("/")
async def root():
    """Endpoint raiz para teste básico."""
    logger.info("request_received", endpoint="/", method="GET")
    return {"message": "WebSocket Service is running"}

@app.get("/health")
async def health_check():
    """Endpoint para verificação de saúde do serviço."""
    logger.info("health_check_received")
    return {"status": "healthy"}

@app.get("/metrics")
async def metrics():
    """Endpoint para expor métricas do Prometheus."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """Endpoint WebSocket para comunicação em tempo real."""
    await websocket.accept()
    ws_connections_total.inc()
    logger.info("websocket_connection_accepted")

    try:
        while True:
            # Receber mensagem
            data = await websocket.receive_text()
            ws_messages_total.labels(direction="received").inc()
            logger.info("websocket_message_received", message=data)

            # Processar mensagem (echo neste exemplo)
            response = {"message": f"Echo: {data}"}
            
            # Enviar resposta
            await websocket.send_text(json.dumps(response))
            ws_messages_total.labels(direction="sent").inc()
            logger.info("websocket_message_sent", response=response)

    except Exception as e:
        logger.error("websocket_error", error=str(e))
    finally:
        logger.info("websocket_connection_closed")

if __name__ == "__main__":
    logger.info("service_starting", service="websocket")
    uvicorn.run(app, host="0.0.0.0", port=8765) 