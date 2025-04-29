# Comparativo: Ingress Controller vs API Gateway em KIND

Este projeto automatiza a criação de um ambiente de testes para comparar desempenho e funcionalidades entre diferentes soluções de Ingress Controller e API Gateway em um cluster Kubernetes local usando KIND (Kubernetes IN Docker).

A estrutura foi pensada para suportar múltiplos protocolos (HTTP, HTTPS, gRPC, TCP) e agora utiliza namespaces separados para isolar os ambientes HTTP e HTTPS.

## Estrutura do Projeto

```
comparativo-ingress-vs-apigw/
│
├── certs/
├── kind/
├── manifests/
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
│   └── tcp/
│       ├── app/
│       └── nginx-apigw/
├── scripts/
└── tests/
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
    └── tcp/
        ├── functional/
        └── performance/
```

- **Cada ambiente (HTTP/HTTPS) tem seu próprio backend, service e namespace.**
- O Nginx API Gateway faz proxy para o serviço correto em cada namespace.

## Manifests de Aplicação de Teste

O projeto inclui exemplos de aplicações de teste para cada protocolo, cada uma rodando em uma porta diferente:

### HTTP (porta 8081)
- **Deployment e Service:** `manifests/http/app/deployment.yaml`
  - Cria um pod rodando o container `hashicorp/http-echo` na porta 8081.
  - Service expõe a aplicação internamente na porta 8081.
- **Ingress:** `manifests/http/app/ingress.yaml`
  - Expõe o serviço HTTP via Nginx Ingress Controller, acessível em `http://http.localtest.me:8080`.

### gRPC (porta 50051)
- **Deployment e Service:** `manifests/grpc/app/deployment.yaml`
  - Cria um pod rodando um container placeholder (substitua pela sua app gRPC real) na porta 50051.
  - Service expõe a aplicação internamente na porta 50051.

### TCP (porta 9000)
- **Deployment e Service:** `manifests/tcp/app/deployment.yaml`
  - Cria um pod rodando o container `hashicorp/tcp-echo` na porta 9000.
  - Service expõe a aplicação internamente na porta 9000.

## Automação dos Testes

O script `scripts/test-all-protocols.ps1` automatiza o deploy e o teste dos três protocolos:

- Aplica todos os manifests (HTTP, gRPC, TCP)
- Aguarda os pods ficarem prontos
- Testa HTTP automaticamente
- Abre port-forward para gRPC e TCP
- Testa TCP automaticamente e fecha o port-forward

### Como usar

No PowerShell:
```powershell
./scripts/test-all-protocols.ps1
```

### O que esperar
- HTTP: O script mostra a resposta do serviço HTTP ("Hello from HTTP").
- gRPC: O port-forward é aberto em background. Teste com [grpcurl](https://github.com/fullstorydev/grpcurl):
  ```powershell
  grpcurl -plaintext localhost:50051 list
  grpcurl -plaintext -d '{"greeting": "Murilo"}' localhost:50051 grpcbin.GRPCBin/Unary
  ```
- TCP: O script testa a conexão TCP automaticamente. Para testar manualmente:
  ```powershell
  nc localhost 9000
  # ou
  telnet localhost 9000
  # Digite algo e pressione Enter para ver o echo
  ```

### Observações
- Sempre que o cluster for recriado, execute o script para restaurar todo o ambiente.
- O port-forward para gRPC permanece aberto até ser fechado manualmente ou pelo sistema.
- O teste TCP é totalmente automatizado.

## Benchmark de Performance HTTP e HTTPS

Agora há dois scripts separados para benchmark:

- **HTTP:** `tests/http/performance/run-http-benchmark.ps1`
- **HTTPS:** `tests/https/performance/run-https-benchmark.ps1`

Ambos executam o benchmark com [hey](https://github.com/rakyll/hey) e coletam métricas de uso de CPU/memória dos containers via `docker stats` **em paralelo**, garantindo que os dados coletados sejam do mesmo instante do teste.

- Os resultados são salvos em:
  - `tests/http/performance/results/hey-http-result.txt` e `docker-stats-http.csv`
  - `tests/https/performance/results/hey-https-result.txt` e `docker-stats-https.csv`

### Como usar

Para HTTP:
```powershell
./tests/http/performance/run-http-benchmark.ps1
```

Para HTTPS:
```powershell
./tests/https/performance/run-https-benchmark.ps1
```

### Metodologia
- O benchmark (`hey.exe`) é executado em background.
- As métricas do Docker são coletadas em paralelo, durante toda a execução do teste.
- Isso garante que os dados de performance e uso de recursos sejam comparáveis entre HTTP e HTTPS.

### Observação
- Se o download automático do `hey.exe` falhar, baixe manualmente do [site oficial](https://github.com/rakyll/hey) e coloque na pasta do script.

## Protocolos Suportados
- HTTP/HTTPS
- gRPC
- TCP

## Observações
- Adicione novos protocolos criando novas pastas em `manifests/` e `tests/`.
- Os manifests e scripts de cada protocolo são independentes para facilitar a manutenção e comparação.

## Como usar

### Ingress Controller (HTTP e HTTPS)
- HTTP: aplique os manifests em `manifests/http/nginx-ingress/` e `manifests/http/app/`
- HTTPS: aplique o manifest em `manifests/https/nginx-ingress/ingress-https.yaml` após criar o Secret TLS

### Nginx como API Gateway (HTTP e HTTPS)
- HTTP: aplique os manifests em `manifests/http/nginx-apigw/`
  - Isso irá criar:
    - Um Deployment do Nginx (`nginx-apigw`) configurado como API Gateway, montando o configmap `nginx-apigw-config` com o arquivo `nginx.conf`.
    - O Nginx escuta na porta 80 e faz proxy para o serviço http-echo na porta 8081.
    - O acesso pode ser feito via port-forward ou criando um Service do tipo NodePort/LoadBalancer, se desejar expor externamente.
  - Exemplo de port-forward:
    ```powershell
    kubectl port-forward deployment/nginx-apigw 8082:80
    # Acesse http://localhost:8082/
    ```
- HTTPS: aplique os manifests em `manifests/https/nginx-apigw/`

### Setup automatizado de HTTPS
- Use o script `scripts/https/setup-https.ps1` para gerar o certificado, criar o Secret e aplicar o Ingress HTTPS

### Teste de acesso
- HTTP: http://localhost:8082/ (API Gateway via port-forward) ou http://localhost:8080/ (Ingress)
- HTTPS: https://localhost:8444/ (API Gateway) ou https://https.localtest.me:8443/ (Ingress)

## Benchmark HTTP simultâneo: Ingress Controller vs API Gateway

Para comparar o desempenho dos dois caminhos sob a mesma carga e no mesmo instante, utilize os scripts:

- `tests/http/performance/run-http-benchmark-ingress.ps1` (Ingress Controller, porta 8080)
- `tests/http/performance/run-http-benchmark-apigw.ps1` (API Gateway, porta 8082)

Cada script:
- Executa o benchmark com [hey](https://github.com/rakyll/hey) para o respectivo endpoint
- Coleta métricas do Docker em paralelo, salvando em arquivos separados

### Como rodar simultaneamente
Abra dois terminais e execute:

**Terminal 1:**
```powershell
./tests/http/performance/run-http-benchmark-ingress.ps1
```

**Terminal 2:**
```powershell
./tests/http/performance/run-http-benchmark-apigw.ps1
```

Ou rode ambos em background:
```powershell
Start-Process powershell -ArgumentList "-NoExit", "-Command", ".\tests\http\performance\run-http-benchmark-ingress.ps1"
Start-Process powershell -ArgumentList "-NoExit", "-Command", ".\tests\http\performance\run-http-benchmark-apigw.ps1"
```

### Resultados
- Ingress Controller: `tests/http/performance/results/docker-stats-http-ingress.csv` e `hey-http-ingress-result.txt`
- API Gateway: `tests/http/performance/results/docker-stats-http-apigw.csv` e `hey-http-apigw-result.txt`

Compare os arquivos para análise de desempenho e uso de recursos de cada solução sob a mesma carga.

## Observação sobre NodePort
Em clusters KIND/Kubernetes, os NodePorts devem estar no range **30000-32767**. Os exemplos deste projeto usam:
- API Gateway HTTP: `http://localhost:30082/`
- API Gateway HTTPS: `https://localhost:30443/`
- Ingress Controller HTTP: `http://localhost:8080/` (ajuste conforme seu Service/port-forward)
- Ingress Controller HTTPS: (ajuste conforme seu Service/port-forward ou NodePort)

Certifique-se de atualizar os scripts de benchmark e os manifests para refletir essas portas ao rodar os testes.

### Como rodar benchmarks HTTP simultâneos
- Ingress Controller: `tests/http/performance/run-http-benchmark-ingress.ps1` (porta 8080)
- API Gateway: `tests/http/performance/run-http-benchmark-apigw.ps1` (porta 30082)

### Como rodar benchmarks HTTPS
- API Gateway: `https://localhost:30443/` (ajuste o script se necessário)

## Setup automatizado do ambiente

Basta rodar:

```powershell
./scripts/setup-environment.ps1
```

Esse script irá:
- Criar o cluster KIND com mapeamento de portas
- Garantir os namespaces `http` e `https`
- Instalar o Nginx Ingress Controller
- Gerar e aplicar o Secret TLS para HTTPS
- Aplicar todos os manifests nos namespaces corretos (HTTP, HTTPS, gRPC)
- **Executar testes automatizados de gRPC:**
  - Testa o acesso gRPC via API Gateway (nginx-apigw) usando port-forward e grpcurl em Docker
  - Testa o acesso gRPC via Ingress Controller (NodePort 30900) usando grpcurl em Docker

Ao final, o ambiente estará pronto para benchmarks e testes. Os resultados dos testes gRPC são exibidos no terminal.

Se quiser rodar benchmarks ou testes funcionais adicionais, consulte os scripts em `tests/` ou execute `./scripts/test-all-protocols.ps1`.

## Como funcionam os backends

- **HTTP:**
  - Namespace: `http`
  - Deployment/Service: `http-echo`
  - Responde "Hello from HTTP"
- **HTTPS:**
  - Namespace: `https`
  - Deployment/Service: `https-echo`
  - Responde "Hello from HTTPS"

## Nginx API Gateway (nginx.conf)

- Porta 80: proxy para `http-echo.http.svc.cluster.local:8081`
- Porta 443: proxy para `https-echo.https.svc.cluster.local:8081`

## Benchmarks e Testes

Scripts de benchmark para HTTP e HTTPS, tanto para Ingress Controller quanto para API Gateway:

- HTTP Ingress: `tests/http/performance/run-http-benchmark-ingress.ps1`
- HTTP API Gateway: `tests/http/performance/run-http-benchmark-apigw.ps1`
- HTTPS Ingress: `tests/https/performance/run-https-benchmark-ingress.ps1`
- HTTPS API Gateway: `tests/https/performance/run-https-benchmark-apigw.ps1`

Cada script executa o benchmark e coleta métricas do Docker em paralelo, salvando resultados separados.

## Teste automatizado de todos os protocolos

Rode:
```powershell
./scripts/test-all-protocols.ps1
```
Esse script aplica os manifests, aguarda os pods (incluindo https-echo no namespace https) e executa testes automatizados para HTTP, HTTPS, gRPC e TCP.

## Boas práticas e organização

- **Namespaces separados** para HTTP e HTTPS garantem isolamento e clareza.
- **Nomes distintos** para os backends (`http-echo` e `https-echo`).
- **Automação total** do setup e deploy.
- **Benchmarks e testes** facilmente reproduzíveis.

Se precisar de instruções detalhadas para qualquer etapa, consulte os scripts ou peça por exemplos específicos!

## Teste gRPC via Docker (grpcurl)

Se não quiser instalar o grpcurl localmente, você pode testar o acesso gRPC usando Docker:

```sh
# Teste via API Gateway (nginx-apigw, porta 30552)
docker run --rm --network=host fullstorydev/grpcurl -plaintext localhost:30552 list

# Teste via Ingress NGINX (porta 30551)
docker run --rm --network=host fullstorydev/grpcurl -plaintext localhost:30551 list
```

> Obs: No Windows, o parâmetro --network=host pode não funcionar como esperado. Se necessário, use o IP do host em vez de localhost. 