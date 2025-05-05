# Serviços de Protocolo

Este projeto contém implementações de diferentes serviços usando vários protocolos de comunicação para fins de teste e comparação.

## Estrutura do Projeto

```
tcc3/
├── docker/
│   ├── Dockerfile.base
│   ├── requirements.base.txt
│   ├── http/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── src/
│   │       └── main.py
│   ├── https/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── src/
│   │       └── main.py
│   ├── websocket/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── src/
│   │       └── main.py
│   ├── graphql/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── src/
│   │       └── main.py
│   └── tcp/
│       ├── Dockerfile
│       ├── requirements.txt
│       └── src/
│           └── main.py
└── manifests/
    ├── ingress-controller/
    │   ├── http/
    │   ├── https/
    │   ├── websocket/
    │   ├── graphql/
    │   └── tcp/
    └── api-gateway/
        ├── http/
        ├── https/
        ├── websocket/
        ├── graphql/
        └── tcp/
```

## Serviços Disponíveis

### HTTP Service (Porta 8080)
- Implementado com FastAPI
- Endpoints:
  - GET /: Endpoint raiz
  - GET /health: Health check
  - GET /metrics: Métricas Prometheus

### HTTPS Service (Porta 8443)
- Implementado com FastAPI + SSL
- Endpoints:
  - GET /: Endpoint raiz
  - GET /health: Health check
  - GET /metrics: Métricas Prometheus

### WebSocket Service (Porta 8765)
- Implementado com FastAPI + WebSockets
- Endpoints:
  - GET /: Endpoint raiz
  - GET /health: Health check
  - GET /metrics: Métricas Prometheus
  - WS /ws: Endpoint WebSocket

### GraphQL Service (Porta 8080)
- Implementado com FastAPI + Strawberry
- Endpoints:
  - GET /: Endpoint raiz
  - GET /health: Health check
  - GET /metrics: Métricas Prometheus
  - POST /graphql: Endpoint GraphQL

### TCP Service (Porta 5000)
- Implementado com asyncio
- Servidor TCP puro com suporte a:
  - Mensagens em texto plano
  - Mensagens JSON
  - Métricas Prometheus (Porta 8081)

## Construindo os Serviços

1. Primeiro, construa a imagem base:
```bash
docker build -f docker/Dockerfile.base -t tcc3-base .
```

2. Em seguida, construa cada serviço:
```bash
docker build -t tcc3-http docker/http
docker build -t tcc3-https docker/https
docker build -t tcc3-websocket docker/websocket
docker build -t tcc3-graphql docker/graphql
docker build -t tcc3-tcp docker/tcp
```

## Executando os Serviços

### Com Docker:
```bash
# HTTP
docker run -p 8080:8080 tcc3-http

# HTTPS
docker run -p 8443:8443 -v $(pwd)/certs:/app/certs tcc3-https

# WebSocket
docker run -p 8765:8765 tcc3-websocket

# GraphQL
docker run -p 8080:8080 tcc3-graphql

# TCP
docker run -p 5000:5000 -p 8081:8081 tcc3-tcp
```

### Com Kubernetes:
```bash
# Aplicar manifestos do Ingress Controller
kubectl apply -f manifests/ingress-controller/

# Aplicar manifestos do API Gateway
kubectl apply -f manifests/api-gateway/
```

## Monitoramento

Todos os serviços expõem métricas Prometheus que podem ser coletadas para monitoramento:

- Serviços HTTP/HTTPS/WebSocket/GraphQL: `/metrics` na porta do serviço
- Serviço TCP: Porta 8081

## Testes

Cada serviço inclui endpoints de health check para verificar sua disponibilidade:

- HTTP/HTTPS/WebSocket/GraphQL: GET /health
- TCP: Conexão na porta 5000

## Segurança

- O serviço HTTPS requer certificados SSL válidos em `/app/certs/`
- Todos os serviços incluem logging estruturado
- Métricas Prometheus para monitoramento
- Graceful shutdown implementado 