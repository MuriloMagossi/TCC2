# scripts/setup-environment.ps1

# Definir o diretório raiz do projeto
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# =========================
# 1. Verificação de pré-requisitos e criação do cluster
# =========================
Write-Host "==> Verificando pré-requisitos e criando cluster KIND..." -ForegroundColor Cyan

# Verificar se o cluster já existe
$clusterExists = kind get clusters | Select-String -Pattern "comparativo-ingress-apigw" -Quiet

if ($clusterExists) {
    Write-Host "[INFO] Cluster 'comparativo-ingress-apigw' já existe. Removendo antes de criar novamente..." -ForegroundColor Yellow
    kind delete cluster --name comparativo-ingress-apigw
}

# =========================
# 2. Criação do cluster
# =========================
Write-Host "==> Criando o cluster KIND..." -ForegroundColor Cyan
kind create cluster --config "$projectRoot/kind/kind-config.yaml" --name comparativo-ingress-apigw

# =========================
# 3. Aguardar node ficar pronto
# =========================
Write-Host "==> Aguardando node ficar Ready..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready node/comparativo-ingress-apigw-control-plane --timeout=60s

Write-Host "==> Cluster criado e node pronto!" -ForegroundColor Green
kubectl get nodes

# =========================
# 4. Criar namespaces
# =========================
Write-Host "==> Garantindo namespaces 'http', 'https', 'grpc', 'tcp', 'websocket' e 'graphql'..." -ForegroundColor Cyan
$namespaces = kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'

if (-not ($namespaces -match "http")) { kubectl create namespace http }
if (-not ($namespaces -match "https")) { kubectl create namespace https }
if (-not ($namespaces -match "grpc")) { kubectl create namespace grpc }
if (-not ($namespaces -match "tcp")) { kubectl create namespace tcp }
if (-not ($namespaces -match "websocket")) { kubectl create namespace websocket }
if (-not ($namespaces -match "graphql")) { kubectl create namespace graphql }

# =========================
# 5. Setup do Ingress Controller
# =========================
Write-Host "==> Rotulando node do KIND com ingress-ready=true..." -ForegroundColor Cyan
kubectl label node comparativo-ingress-apigw-control-plane ingress-ready=true

Write-Host "==> Instalando Nginx Ingress Controller..." -ForegroundColor Cyan
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s

# =========================
# 6. Instalação dos API Gateways
# =========================
Write-Host "==> Instalando Nginx API Gateway para todos os protocolos..." -ForegroundColor Cyan
kubectl apply -f "$projectRoot/manifests/http/nginx-apigw/"
kubectl apply -f "$projectRoot/manifests/https/nginx-apigw/"
kubectl apply -f "$projectRoot/manifests/grpc/nginx-apigw/"
kubectl apply -f "$projectRoot/manifests/tcp/nginx-apigw/"
kubectl apply -f "$projectRoot/manifests/websocket/nginx-apigw/"
kubectl apply -f "$projectRoot/manifests/graphql/nginx-apigw/"

# =========================
# 7. Criar Secret TLS para HTTPS
# =========================
Write-Host "==> Garantindo Secret TLS para HTTPS..." -ForegroundColor Cyan
$tlsExists = kubectl get secret http-echo-tls -n https 2>$null
if (-not $tlsExists) {
    kubectl create secret tls http-echo-tls --cert="$projectRoot/certs/server.crt" --key="$projectRoot/certs/server.key" -n https
}
Write-Host "==> Secret TLS criado." -ForegroundColor Green

# =========================
# 8. Build de imagens locais
# =========================
# Build e load da imagem TCP echo
Write-Host "==> Buildando imagem local/tcp-echo:latest..." -ForegroundColor Cyan
docker build -t local/tcp-echo:latest -f "$projectRoot/Dockerfile" "$projectRoot"
kind load docker-image local/tcp-echo:latest --name comparativo-ingress-apigw

# Garantir diretórios de teste
Write-Host "==> Garantindo estrutura de diretórios para testes..." -ForegroundColor Cyan
$testDirs = @(
    "$projectRoot/tests/websocket/functional",
    "$projectRoot/tests/websocket/performance",
    "$projectRoot/tests/websocket/performance/results",
    "$projectRoot/tests/graphql/functional",
    "$projectRoot/tests/graphql/performance",
    "$projectRoot/tests/graphql/performance/results"
)

foreach ($dir in $testDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "[INFO] Criado diretório: $dir" -ForegroundColor Yellow
    }
}

# Build e load da imagem WebSocket
Write-Host "==> Buildando imagem local/websocket-echo:latest..." -ForegroundColor Cyan
docker build -t local/websocket-echo:latest -f "$projectRoot/manifests/websocket/app/Dockerfile" "$projectRoot/manifests/websocket/app/"
kind load docker-image local/websocket-echo:latest --name comparativo-ingress-apigw

# Build e load da imagem GraphQL
Write-Host "==> Buildando imagem local/graphql-echo:latest..." -ForegroundColor Cyan
docker build -t local/graphql-echo:latest -f "$projectRoot/manifests/graphql/app/Dockerfile" "$projectRoot/manifests/graphql/app/"
kind load docker-image local/graphql-echo:latest --name comparativo-ingress-apigw

# =========================
# 9. Verificar ferramentas de benchmark
# =========================
Write-Host "==> Verificando ferramentas de benchmarking..." -ForegroundColor Cyan

# Verificar hey (para HTTP e GraphQL)
if (-not (Test-Path "$projectRoot/hey.exe")) {
    Write-Host "[INFO] hey.exe não encontrado. Será baixado quando necessário." -ForegroundColor Yellow
}

# Verificar bombardier (para WebSocket)
if (-not (Test-Path "$projectRoot/bombardier.exe")) {
    Write-Host "[INFO] bombardier.exe não encontrado. Será baixado quando necessário." -ForegroundColor Yellow
}

Write-Host "`n==> Ambiente pronto! Execute ./scripts/test-all-protocols.ps1 para testar os protocolos." -ForegroundColor Green 