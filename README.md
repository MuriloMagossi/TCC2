# Comparativo: Ingress Controller vs API Gateway em KIND

Este projeto automatiza a criação de um ambiente de testes para comparar desempenho e funcionalidades entre diferentes soluções de Ingress Controller e API Gateway em um cluster Kubernetes local usando KIND (Kubernetes IN Docker).

A estrutura foi pensada para suportar múltiplos protocolos (HTTP, HTTPS, gRPC, TCP, WebSocket, GraphQL) e agora utiliza namespaces separados para isolar os ambientes de cada protocolo.

## Estrutura do Projeto

```
comparativo-ingress-vs-apigw/
│
├── certs/
├── kind/
├── manifests/
│   ├── graphql/
│   │   ├── app/
│   │   └── nginx-apigw/
│   ├── grpc/
│   │   ├── app/
│   │   └── nginx-apigw/
│   ├── http/
│   │   ├── app/
│   │   ├── nginx-apigw/
│   │   └── nginx-ingress/
│   ├── https/
│   │   ├── app/
│   │   ├── nginx-apigw/
│   │   └── nginx-ingress/
│   ├── tcp/
│   │   ├── app/
│   │   └── nginx-apigw/
│   └── websocket/
│       ├── app/
│       └── nginx-apigw/
├── scripts/
└── tests/
    ├── graphql/
    │   ├── functional/
    │   │   └── results/
    │   └── performance/
    │       └── results/
    ├── grpc/
    │   ├── functional/
    │   └── performance/
    │       └── results/
    ├── http/
    │   ├── functional/
    │   └── performance/
    │       └── results/
    ├── https/
    │   ├── functional/
    │   └── performance/
    │       └── results/
    ├── tcp/
    │   ├── functional/
    │   └── performance/
    │       └── results/
    └── websocket/
        ├── functional/
        │   └── results/
        └── performance/
            └── results/
```

- **Cada protocolo tem seu próprio backend, service e namespace.**
- O Nginx API Gateway faz proxy para o serviço correto em cada namespace.

## Manifests de Aplicação de Teste

O projeto inclui exemplos de aplicações de teste para cada protocolo, cada uma rodando em uma porta diferente:

### HTTP (porta 8081)
- **Deployment e Service:** `manifests/http/app/deployment.yaml`
  - Cria um pod rodando o container `hashicorp/http-echo` na porta 8081.
  - Service expõe a aplicação internamente na porta 8081.
- **Ingress:** `manifests/http/app/ingress.yaml`
  - Expõe o serviço HTTP via Nginx Ingress Controller, acessível em `http://http.localtest.me:8080`.

### HTTPS (porta 8081)
- **Deployment e Service:** `manifests/https/app/deployment.yaml`
  - Cria um pod rodando o container `hashicorp/http-echo` na porta 8081.
  - Service expõe a aplicação internamente na porta 8081.
- **Ingress:** `manifests/https/app/ingress.yaml`
  - Expõe o serviço HTTPS via Nginx Ingress Controller, acessível em `https://https.localtest.me:8443`.

### gRPC (porta 50051)
- **Deployment e Service:** `manifests/grpc/app/deployment.yaml`
  - Cria um pod rodando um container placeholder (substitua pela sua app gRPC real) na porta 50051.
  - Service expõe a aplicação internamente na porta 50051.

### TCP (porta 9000)
- **Deployment e Service:** `manifests/tcp/app/deployment.yaml`
  - Cria um pod rodando o container `hashicorp/tcp-echo` na porta 9000.
  - Service expõe a aplicação internamente na porta 9000.

### WebSocket (porta 9000)
- **Deployment e Service:** `manifests/websocket/app/deployment.yaml`
  - Cria um pod rodando um servidor WebSocket na porta 9000
  - Service expõe a aplicação internamente na porta 9000
  - **Importante:** WebSocket é um protocolo de aplicação que opera sobre HTTP/HTTPS e TCP. Ele começa com uma conexão HTTP normal (handshake) e depois é "upgraded" para WebSocket, permitindo comunicação bidirecional.

### GraphQL (porta 9000)
- **Deployment e Service:** `manifests/graphql/app/deployment.yaml`
  - Cria um pod rodando um servidor GraphQL (Apollo Server) na porta 9000
  - Service expõe a aplicação internamente na porta 9000
  - **Importante:** GraphQL é uma linguagem de consulta e manipulação de dados, não um protocolo de rede. As requisições GraphQL são transportadas via HTTP/HTTPS.
  - O servidor implementa endpoints GraphQL que podem ser acessados via HTTP POST para `/graphql`

## Protocolos Suportados
- HTTP/HTTPS (incluindo GraphQL sobre HTTP)
- gRPC
- TCP
- WebSocket (protocolo de aplicação sobre HTTP/HTTPS)

## Automação dos Testes

O script `scripts/test-all-protocols.ps1` automatiza o deploy e o teste de todos os protocolos:

- Aplica todos os manifests (HTTP, HTTPS, gRPC, TCP, WebSocket, GraphQL)
- Aguarda os pods ficarem prontos
- Testa cada protocolo automaticamente
- Abre port-forward quando necessário
- Fecha port-forwards ao término dos testes

### Como usar

No PowerShell:
```powershell
./scripts/test-all-protocols.ps1
```

## Setup automatizado do ambiente

Basta rodar:

```powershell
./scripts/setup-environment.ps1
```

Esse script irá:
- Criar o cluster KIND com mapeamento de portas
- Garantir os namespaces para cada protocolo
- Instalar o Nginx Ingress Controller
- Gerar e aplicar o Secret TLS para HTTPS
- Aplicar todos os manifests nos namespaces corretos
- Executar testes automatizados básicos

Ao final, o ambiente estará pronto para benchmarks e testes. Os resultados dos testes iniciais são exibidos no terminal.

## Arquitetura

### Portas NodePort
- **HTTP:**
  - API Gateway: 30082
  - Ingress Controller: 8080
- **HTTPS:**
  - API Gateway: 30443
  - Ingress Controller: 8443
- **gRPC:**
  - API Gateway: 30553
  - Ingress Controller: 30900
- **TCP:**
  - API Gateway: 30901
  - Ingress Controller: 30902
- **WebSocket:**
  - API Gateway: (porta específica)
  - Ingress Controller: (porta específica)
- **GraphQL:**
  - API Gateway: (porta específica)
  - Ingress Controller: (porta específica)

### Backends
- **HTTP:**
  - Namespace: `http`
  - Deployment/Service: `http-echo`
  - Responde "Hello from HTTP"
- **HTTPS:**
  - Namespace: `https`
  - Deployment/Service: `https-echo`
  - Responde "Hello from HTTPS"
- **gRPC:**
  - Namespace: `grpc`
  - Deployment/Service: `grpc-echo`
  - Serviço gRPC baseado em grpcbin
- **TCP:**
  - Namespace: `tcp`
  - Deployment/Service: `tcp-echo`
  - Responde com echo do que é enviado
- **WebSocket:**
  - Namespace: `websocket`
  - Deployment/Service: `websocket-echo`
  - Implementação específica para WebSocket
- **GraphQL:**
  - Namespace: `graphql`
  - Deployment/Service: `graphql-service`
  - Implementação específica para GraphQL

## Testes por Protocolo

### HTTP/HTTPS

#### Testes Funcionais
- `test-http-basic.ps1` - Teste básico de conectividade HTTP para verificar se o serviço está funcionando corretamente, testando tanto o acesso via API Gateway quanto diretamente ao serviço.

#### Testes de Performance
- `run-http-benchmark-apigw.ps1` - Benchmark específico para testar a performance do API Gateway.
- `run-http-benchmark-ingress.ps1` - Benchmark específico para testar a performance do acesso direto ao serviço.
- `analyze-http-results.ps1` - Análise e comparação dos resultados de benchmark.

#### Como Executar os Testes

Pré-requisitos:
- Cluster Kubernetes em execução
- API Gateway e serviço HTTP implantados
- PowerShell 5.1+
- (Opcional) Node.js para testes avançados de HTTP

Teste Funcional Básico:
```powershell
./tests/http/functional/test-http-basic.ps1
```

Benchmarks de Performance:
```powershell
# Testar API Gateway
./tests/http/performance/run-http-benchmark-apigw.ps1

# Testar Serviço direto
./tests/http/performance/run-http-benchmark-ingress.ps1

# Analisar resultados
./tests/http/performance/analyze-http-results.ps1
```

#### Métricas Avaliadas
- Taxa de sucesso de conexões
- Tempo médio de conexão (latência)
- Conexões por segundo (throughput)
- Uso de recursos do sistema

### gRPC

#### Testes Funcionais
- `test-grpc-basic.ps1` - Teste básico de conectividade gRPC para verificar se o serviço está funcionando corretamente, testando tanto o acesso via API Gateway quanto diretamente ao serviço.

#### Testes de Performance
- `run-grpc-benchmark-apigw.ps1` - Benchmark específico para testar a performance do API Gateway usando a ferramenta 'hey', incluindo testes para o endpoint gRPC regular e o endpoint de echo (baixo processamento).
- `run-grpc-benchmark-ingress.ps1` - Benchmark específico para testar a performance do acesso direto ao serviço, também usando 'hey'.
- `analyze-grpc-results.ps1` - Script para analisar e comparar os resultados dos benchmarks, produzindo estatísticas e recomendações.

#### Como Executar os Testes

Pré-requisitos:
- Cluster Kubernetes em execução
- API Gateway e serviço gRPC implantados
- PowerShell 5.1+
- A ferramenta 'hey' (baixada automaticamente pelos scripts de benchmark se necessário)

Teste Funcional Básico:
```powershell
./tests/grpc/functional/test-grpc-basic.ps1
```

Benchmarks de Performance:
```powershell
# Testar API Gateway
./tests/grpc/performance/run-grpc-benchmark-apigw.ps1

# Testar Serviço direto
./tests/grpc/performance/run-grpc-benchmark-ingress.ps1

# Analisar resultados
./tests/grpc/performance/analyze-grpc-results.ps1
```

#### Formato dos Resultados

Os testes de performance utilizam a ferramenta 'hey' para gerar resultados padronizados em um formato consistente com os testes HTTP/HTTPS. Os resultados incluem:

- **Sumário de Desempenho**:
  - Duração total do teste
  - Tempos de resposta mais rápido, mais lento e médio
  - Taxa de requisições por segundo
  - Total de dados transferidos

- **Histograma de Tempo de Resposta**:
  - Distribuição visual dos tempos de resposta

- **Distribuição de Latência**:
  - Percentis (10%, 25%, 50%, 75%, 90%, 95%, 99%)

- **Detalhes de Requisição**:
  - Tempo de DNS e conexão
  - Tempo de escrita da requisição
  - Tempo de espera pela resposta
  - Tempo de leitura da resposta

- **Distribuição de Códigos de Status**:
  - Contagem de respostas por código de status HTTP

#### Perspectivas de Análise Comparativa

Os testes comparativos de gRPC fornecem várias perspectivas:

1. **API Gateway vs. Serviço Direto (gRPC completo)**
   - Comparação de desempenho para chamadas gRPC reais

2. **API Gateway vs. Serviço Direto (Echo - baixo processamento)**
   - Comparação de overhead puro de infraestrutura

3. **Processamento vs. Echo no API Gateway**
   - Isolamento do tempo de processamento gRPC

4. **Processamento vs. Echo no Serviço Direto**
   - Isolamento do tempo de processamento gRPC sem overhead do gateway

## Análise Comparativa Geral

Para todos os protocolos testados, a análise comparativa avalia:

1. **API Gateway (Ingress Controller)**
   - Vantagens:
     - Centralização de segurança e autenticação
     - Gerenciamento de tráfego e roteamento unificado
   - Possíveis desvantagens:
     - Possível aumento na latência devido à camada adicional

2. **Acesso Direto ao Serviço**
   - Vantagens:
     - Potencialmente menor latência
     - Comunicação direta sem intermediários
   - Desvantagens:
     - Requer gerenciamento de segurança em cada serviço
     - Ausência de políticas centralizadas

## Considerações para Produção

Para aplicações em produção, considere:
- Requisitos de segurança e autenticação
- Necessidade de gerenciamento de tráfego
- Sensibilidade à latência
- Requisitos de escalabilidade

Os scripts de análise fornecem recomendações específicas com base nos resultados dos benchmarks, ajudando na tomada de decisão entre as abordagens.

## Boas práticas e organização

- **Namespaces separados** para cada protocolo garantem isolamento e clareza.
- **Nomes distintos** para os backends.
- **Automação total** do setup e deploy.
- **Benchmarks e testes** facilmente reproduzíveis.

## Resultados
Resultados dos testes de performance são armazenados no diretório `/tests/{protocolo}/performance/results`.

## Próximos passos
1. Aprimorar os testes de performance para carga contínua
2. Adicionar suporte a mais métricas de performance
3. Visualização gráfica de resultados comparativos

### WebSocket

#### Testes Disponíveis

##### Testes Funcionais
- `test-websocket-basic.ps1` - Teste básico de conectividade WebSocket para verificar se o serviço está funcionando corretamente, testando tanto o acesso via API Gateway quanto diretamente ao serviço.

##### Testes de Performance
- `run-websocket-benchmark-apigw.ps1` - Benchmark específico para testar a performance do API Gateway.
- `run-websocket-benchmark-ingress.ps1` - Benchmark específico para testar a performance do acesso direto ao serviço.
- `analyze-websocket-results.ps1` - Análise e comparação dos resultados de benchmark.

#### Como Executar os Testes

Pré-requisitos:
- Cluster Kubernetes em execução
- API Gateway e serviço WebSocket implantados
- PowerShell 5.1+
- (Opcional) Node.js para testes avançados de WebSocket

Teste Funcional Básico:
```powershell
./tests/websocket/functional/test-websocket-basic.ps1
```

Benchmarks de Performance:
```powershell
# Testar API Gateway
./tests/websocket/performance/run-websocket-benchmark-apigw.ps1

# Testar Serviço direto
./tests/websocket/performance/run-websocket-benchmark-ingress.ps1

# Analisar resultados
./tests/websocket/performance/analyze-websocket-results.ps1
```

#### Métricas Avaliadas
- Taxa de sucesso de conexões
- Tempo médio de conexão (latência)
- Conexões por segundo (throughput)
- Uso de recursos do sistema

### GraphQL

#### Testes Disponíveis

##### Testes Funcionais
- `test-graphql-basic.ps1` - Teste básico de consultas GraphQL para verificar se o serviço está funcionando corretamente, testando tanto o acesso via API Gateway quanto diretamente ao serviço.

##### Testes de Performance
- `run-graphql-benchmark-apigw.ps1` - Benchmark específico para testar a performance do API Gateway usando a ferramenta 'hey', enviando requisições HTTP POST com queries GraphQL.
- `run-graphql-benchmark-ingress.ps1` - Benchmark específico para testar a performance do acesso direto ao serviço, também usando 'hey' para enviar requisições HTTP POST com queries GraphQL.
- `analyze-graphql-results.ps1` - Script para analisar e comparar os resultados dos benchmarks, produzindo estatísticas e recomendações.

#### Como Executar os Testes

Pré-requisitos:
- Cluster Kubernetes em execução
- API Gateway e serviço GraphQL implantados
- PowerShell 5.1+
- A ferramenta 'hey' (baixada automaticamente pelos scripts de benchmark se necessário)

Teste Funcional Básico:
```powershell
./tests/graphql/functional/test-graphql-basic.ps1
```

Benchmarks de Performance:
```powershell
# Testar API Gateway
./tests/graphql/performance/run-graphql-benchmark-apigw.ps1

# Testar Serviço direto
./tests/graphql/performance/run-graphql-benchmark-ingress.ps1

# Analisar resultados
./tests/graphql/performance/analyze-graphql-results.ps1
```

#### Formato dos Resultados

Os testes de performance utilizam a ferramenta 'hey' para gerar resultados padronizados em um formato consistente com os testes HTTP/HTTPS. Os resultados incluem:

- **Sumário de Desempenho**:
  - Duração total do teste
  - Tempos de resposta mais rápido, mais lento e médio
  - Taxa de requisições por segundo
  - Total de dados transferidos

- **Histograma de Tempo de Resposta**:
  - Distribuição visual dos tempos de resposta

- **Distribuição de Latência**:
  - Percentis (10%, 25%, 50%, 75%, 90%, 95%, 99%)

- **Detalhes de Requisição**:
  - Tempo de DNS e conexão
  - Tempo de escrita da requisição
  - Tempo de espera pela resposta
  - Tempo de leitura da resposta

- **Distribuição de Códigos de Status**:
  - Contagem de respostas por código de status HTTP

#### Perspectivas de Análise Comparativa

Os testes comparativos de GraphQL fornecem várias perspectivas:

1. **API Gateway vs. Serviço Direto (GraphQL completo)**
   - Comparação de desempenho para consultas GraphQL reais
   - Medição do overhead do API Gateway em requisições HTTP POST com payload GraphQL

2. **API Gateway vs. Serviço Direto (Echo - baixo processamento)**
   - Comparação de overhead puro de infraestrutura
   - Avaliação do impacto do API Gateway em requisições HTTP simples

3. **Processamento vs. Echo no API Gateway**
   - Isolamento do tempo de processamento GraphQL
   - Análise do impacto do parsing e validação de queries GraphQL

4. **Processamento vs. Echo no Serviço Direto**
   - Isolamento do tempo de processamento GraphQL sem overhead do gateway
   - Avaliação do desempenho puro do servidor GraphQL

## Análise Comparativa Geral

Para todos os protocolos testados, a análise comparativa avalia:

1. **API Gateway (Ingress Controller)**
   - Vantagens:
     - Centralização de segurança e autenticação
     - Gerenciamento de tráfego e roteamento unificado
   - Possíveis desvantagens:
     - Possível aumento na latência devido à camada adicional

2. **Acesso Direto ao Serviço**
   - Vantagens:
     - Potencialmente menor latência
     - Comunicação direta sem intermediários
   - Desvantagens:
     - Requer gerenciamento de segurança em cada serviço
     - Ausência de políticas centralizadas

## Considerações para Produção

Para aplicações em produção, considere:
- Requisitos de segurança e autenticação
- Necessidade de gerenciamento de tráfego
- Sensibilidade à latência
- Requisitos de escalabilidade

Os scripts de análise fornecem recomendações específicas com base nos resultados dos benchmarks, ajudando na tomada de decisão entre as abordagens.

## Boas práticas e organização

- **Namespaces separados** para cada protocolo garantem isolamento e clareza.
- **Nomes distintos** para os backends.
- **Automação total** do setup e deploy.
- **Benchmarks e testes** facilmente reproduzíveis.

## Resultados
Resultados dos testes de performance são armazenados no diretório `/tests/{protocolo}/performance/results`.

## Próximos passos
1. Aprimorar os testes de performance para carga contínua
2. Adicionar suporte a mais métricas de performance
3. Visualização gráfica de resultados comparativos 