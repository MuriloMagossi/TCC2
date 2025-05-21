# Comparativo: Ingress Controller vs API Gateway em KIND

Este projeto automatiza a criação de um ambiente de testes para comparar desempenho e funcionalidades entre diferentes soluções de Ingress Controller e API Gateway em um cluster Kubernetes local usando KIND (Kubernetes IN Docker).

## 🚀 Guia de Início Rápido

### Pré-requisitos
- Docker Desktop instalado e em execução
- KIND instalado
- kubectl instalado
- PowerShell 5.1+

### Passo a Passo para Execução

1. **Configuração do Ambiente**
   ```powershell
   # Execute o script de setup para criar o cluster e configurar o ambiente
   ./scripts/setup-environment.ps1
   ```
   Este script irá:
   - Criar um cluster KIND com todas as configurações necessárias
   - Configurar os namespaces para cada protocolo
   - Instalar o Nginx Ingress Controller
   - Configurar os API Gateways
   - Preparar os certificados TLS para HTTPS
   - Buildar e carregar as imagens necessárias

2. **Execução dos Testes Funcionais**
   ```powershell
   # Execute o script para testar todos os protocolos
   ./scripts/test-all-protocols.ps1
   ```
   Este script irá:
   - Aplicar todos os manifests necessários
   - Executar testes funcionais básicos para cada protocolo
   - Mostrar um resumo dos resultados

3. **Execução dos Testes de Performance**
   Após os testes funcionais, você pode executar os testes de performance para cada protocolo:

   **HTTP:**
   ```powershell
   # Testar API Gateway
   ./tests/http/performance/run-http-benchmark-apigw.ps1
   # Testar acesso direto
   ./tests/http/performance/run-http-benchmark-ingress.ps1
   # Analisar resultados
   ./tests/http/performance/analyze-http-results.ps1
   ```

   **HTTPS:**
   ```powershell
   # Testar API Gateway
   ./tests/https/performance/run-https-benchmark-apigw.ps1
   # Testar acesso direto
   ./tests/https/performance/run-https-benchmark-ingress.ps1
   # Analisar resultados
   ./tests/https/performance/analyze-https-results.ps1
   ```

   **WebSocket:**
   ```powershell
   # Testar API Gateway
   ./tests/websocket/performance/run-websocket-benchmark-apigw.ps1
   # Testar acesso direto
   ./tests/websocket/performance/run-websocket-benchmark-ingress.ps1
   # Analisar resultados
   ./tests/websocket/performance/analyze-websocket-results.ps1
   ```

   **GraphQL:**
   ```powershell
   # Testar API Gateway
   ./tests/graphql/performance/run-graphql-benchmark-apigw.ps1
   # Testar acesso direto
   ./tests/graphql/performance/run-graphql-benchmark-ingress.ps1
   # Analisar resultados
   ./tests/graphql/performance/analyze-graphql-results.ps1
   ```

### 📊 Resultados
Os resultados dos testes de performance são armazenados em:
```
/tests/{protocolo}/performance/results/
```

### 🔍 O que está sendo testado?

O projeto compara o desempenho entre:
1. Acesso via API Gateway
2. Acesso direto ao serviço (via Ingress Controller)

Para cada protocolo, são avaliados:
- Taxa de sucesso de conexões
- Latência (tempo médio de resposta)
- Throughput (requisições por segundo)
- Uso de recursos do sistema

A estrutura foi pensada para suportar múltiplos protocolos (HTTP, HTTPS, WebSocket, GraphQL) e agora utiliza namespaces separados para isolar os ambientes de cada protocolo.

