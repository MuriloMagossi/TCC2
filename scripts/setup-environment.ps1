# scripts/setup-environment.ps1

# =========================
# 1. Pré-requisitos e criação do cluster KIND
# =========================
Write-Host "==> Verificando pré-requisitos e criando cluster KIND..." -ForegroundColor Cyan
& ./kind/cluster-setup.ps1

# =========================
# 2. Garantir namespaces necessários
# =========================
Write-Host "==> Garantindo namespaces 'http', 'https', 'grpc' e 'tcp'..." -ForegroundColor Cyan
foreach ($ns in @('http','https','grpc','tcp')) {
    if (-not (kubectl get namespace $ns -o name 2 -gt $null)) { kubectl create namespace $ns }
}

# =========================
# 3. Rotular node para Ingress Controller
# =========================
Write-Host "==> Rotulando node do KIND com ingress-ready=true..." -ForegroundColor Cyan
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') ingress-ready=true --overwrite

# =========================
# 4. Instalar e aguardar Nginx Ingress Controller
# =========================
Write-Host "==> Instalando Nginx Ingress Controller..." -ForegroundColor Cyan
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/kind/deploy.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRO] Falha ao instalar o Nginx Ingress Controller." -ForegroundColor Red
    exit 1
}

Write-Host "==> Aguardando Nginx Ingress Controller ficar pronto..." -ForegroundColor Cyan
$ready = $false
for ($i=0; $i -lt 50; $i++) {
    $status = kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers | Select-String " 1/1 " | Select-String "Running"
    if ($status) {
        $ready = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    Write-Host "[ERRO] Nginx Ingress Controller não ficou pronto após 100 segundos." -ForegroundColor Red
    exit 1
}

# =========================
# 5. Instalar Nginx API Gateway para todos os protocolos
# =========================
Write-Host "==> Instalando Nginx API Gateway para todos os protocolos..." -ForegroundColor Cyan
kubectl apply -n http -f manifests/http/nginx-apigw/
kubectl apply -n https -f manifests/https/nginx-apigw/
kubectl apply -n grpc -f manifests/grpc/nginx-apigw/
kubectl apply -n tcp -f manifests/tcp/nginx-apigw/

# =========================
# 6. Garantir Secret TLS para HTTPS
# =========================
Write-Host "==> Garantindo Secret TLS para HTTPS..." -ForegroundColor Cyan
if (-not (kubectl get secret http-echo-tls -o name 2-gt$null)) {
    $certDir = "$PSScriptRoot/../certs"
    if (-not (Test-Path $certDir)) { New-Item -ItemType Directory -Path $certDir | Out-Null }
    $crt = "$certDir/tls.crt"
    $key = "$certDir/tls.key"
    if (-not (Test-Path $crt) -or -not (Test-Path $key)) {
        Write-Host "==> Gerando certificado autoassinado..." -ForegroundColor Cyan
        & openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $key -out $crt -subj "/CN=apigw.localtest.me"
    }
    kubectl create secret tls http-echo-tls --cert=$crt --key=$key
    Write-Host "==> Secret TLS criado." -ForegroundColor Green
} else {
    Write-Host "==> Secret TLS já existe." -ForegroundColor Yellow
}

# =========================
# 7. Build e load da imagem local TCP echo
# =========================
Write-Host "==> Buildando imagem local/tcp-echo:latest..." -ForegroundColor Cyan
$dockerfilePath = "$PSScriptRoot/../Dockerfile"
$contextPath = "$PSScriptRoot/.."
if (Test-Path $dockerfilePath) {
    docker build -t local/tcp-echo:latest $contextPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "==> Carregando imagem local/tcp-echo:latest no KIND..." -ForegroundColor Cyan
        kind load docker-image local/tcp-echo:latest --name comparativo-ingress-apigw
    } else {
        Write-Host "[ERRO] Falha ao buildar a imagem local/tcp-echo:latest." -ForegroundColor Red
    }
} else {
    Write-Host "[AVISO] Dockerfile não encontrado em $dockerfilePath. Pulei build/load da imagem local." -ForegroundColor Yellow
}

# =========================
# 8. Mensagem final
# =========================
Write-Host "\n==> Ambiente pronto! Execute ./scripts/test-all-protocols.ps1 para testar os protocolos." -ForegroundColor Green

# (Futuro) Instalar outros componentes, apps de teste, etc.
# Exemplo:
# Write-Host "==> Instalando API Gateway..." -ForegroundColor Cyan
# kubectl apply -f <manifest do gateway> 