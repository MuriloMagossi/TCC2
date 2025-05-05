from fastapi import FastAPI, Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import strawberry
from strawberry.fastapi import GraphQLRouter
import structlog
import uvicorn
from typing import List, Optional

# Configuração do logger
logger = structlog.get_logger()

# Métricas Prometheus
graphql_requests_total = Counter('graphql_requests_total', 'Total number of GraphQL requests', ['operation'])

# Definição dos tipos GraphQL
@strawberry.type
class Message:
    id: int
    content: str

@strawberry.type
class Query:
    @strawberry.field
    def message(self, id: int) -> Optional[Message]:
        """Consulta uma mensagem pelo ID."""
        graphql_requests_total.labels(operation="query").inc()
        logger.info("graphql_query", operation="message", id=id)
        # Simulação de busca de mensagem
        return Message(id=id, content=f"Message {id}")

    @strawberry.field
    def messages(self) -> List[Message]:
        """Lista todas as mensagens."""
        graphql_requests_total.labels(operation="query").inc()
        logger.info("graphql_query", operation="messages")
        # Simulação de lista de mensagens
        return [Message(id=i, content=f"Message {i}") for i in range(1, 4)]

@strawberry.type
class Mutation:
    @strawberry.mutation
    def create_message(self, content: str) -> Message:
        """Cria uma nova mensagem."""
        graphql_requests_total.labels(operation="mutation").inc()
        logger.info("graphql_mutation", operation="create_message", content=content)
        # Simulação de criação de mensagem
        return Message(id=1, content=content)

# Criação do schema GraphQL
schema = strawberry.Schema(query=Query, mutation=Mutation)

# Criação da aplicação FastAPI
app = FastAPI(title="GraphQL Service")

# Configuração do router GraphQL
graphql_app = GraphQLRouter(schema)
app.include_router(graphql_app, prefix="/graphql")

@app.get("/")
async def root():
    """Endpoint raiz para teste básico."""
    logger.info("request_received", endpoint="/", method="GET")
    return {"message": "GraphQL Service is running"}

@app.get("/health")
async def health_check():
    """Endpoint para verificação de saúde do serviço."""
    logger.info("health_check_received")
    return {"status": "healthy"}

@app.get("/metrics")
async def metrics():
    """Endpoint para expor métricas do Prometheus."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    logger.info("service_starting", service="graphql")
    uvicorn.run(app, host="0.0.0.0", port=8080) 