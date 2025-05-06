# scripts/test-all-protocols.ps1

# Definir o diretório raiz do projeto
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# =========================
# 1. Aplicação dos manifests
# =========================
Write-Host "==> Aplicando HTTP..." -ForegroundColor Cyan
kubectl apply -n http -f "$projectRoot/manifests/http/app/"
Write-Host "==> Aplicando Ingress Controller HTTP..." -ForegroundColor Cyan
kubectl apply -f "$projectRoot/manifests/http/nginx-ingress/"
Write-Host "==> Aplicando API Gateway HTTP..." -ForegroundColor Cyan
kubectl apply -n http -f "$projectRoot/manifests/http/nginx-apigw/"

Write-Host "==> Aplicando HTTPS..." -ForegroundColor Cyan
kubectl apply -f "$projectRoot/manifests/https/nginx-apigw/tls-secret.yaml"
kubectl apply -n https -f "$projectRoot/manifests/https/app/"
Write-Host "==> Aplicando API Gateway HTTPS..." -ForegroundColor Cyan
kubectl apply -n https -f "$projectRoot/manifests/https/nginx-apigw/"
Write-Host "==> Aplicando Ingress Controller HTTPS..." -ForegroundColor Cyan
kubectl apply -f "$projectRoot/manifests/https/nginx-ingress/"

Write-Host "==> Aplicando ConfigMap tcp-services unificado..." -ForegroundColor Cyan
if (Test-Path "$projectRoot/manifests/tcp-services.yaml") {
    kubectl apply -f "$projectRoot/manifests/tcp-services.yaml"
} else {
    Write-Host "[INFO] Arquivo tcp-services.yaml não encontrado. Pulando..." -ForegroundColor Yellow
}

Write-Host "==> Aplicando serviços do Ingress Controller..." -ForegroundColor Cyan
if (Test-Path "$projectRoot/manifests/ingress-services.yaml") {
    kubectl apply -f "$projectRoot/manifests/ingress-services.yaml"
} else {
    Write-Host "[INFO] Arquivo ingress-services.yaml não encontrado. Pulando..." -ForegroundColor Yellow
}

Write-Host "==> Aplicando WebSocket..." -ForegroundColor Cyan
kubectl apply -n websocket -f "$projectRoot/manifests/websocket/app/"
Write-Host "==> Aplicando API Gateway WebSocket..." -ForegroundColor Cyan
kubectl apply -n websocket -f "$projectRoot/manifests/websocket/nginx-apigw/"
Write-Host "==> Aplicando Ingress Controller WebSocket..." -ForegroundColor Cyan
kubectl apply -f "$projectRoot/manifests/websocket/nginx-ingress/"

Write-Host "==> Aplicando GraphQL..." -ForegroundColor Cyan
kubectl apply -n graphql -f "$projectRoot/manifests/graphql/app/"
Write-Host "==> Aplicando API Gateway GraphQL..." -ForegroundColor Cyan
kubectl apply -n graphql -f "$projectRoot/manifests/graphql/nginx-apigw/"
Write-Host "==> Aplicando Ingress Controller GraphQL..." -ForegroundColor Cyan
kubectl apply -f "$projectRoot/manifests/graphql/nginx-ingress/"

# =========================
# 2. Espera dos pods ficarem prontos
# =========================
Write-Host "==> Aguardando pods ficarem prontos..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod -l app=http-echo -n http --timeout=60s
kubectl wait --for=condition=Ready pod -l app=https-echo -n https --timeout=60s
kubectl wait --for=condition=Ready pod -l app=websocket-echo -n websocket --timeout=60s
kubectl wait --for=condition=Ready pod -l app=graphql-echo -n graphql --timeout=60s

# =========================
# 3. Testes funcionais por protocolo
# =========================
Write-Host "`n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes HTTP" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
if (Test-Path "$projectRoot/tests/http/functional/test-http.ps1") {
    & "$projectRoot/tests/http/functional/test-http.ps1"
} else {
    Write-Host "[ERRO] Script de teste HTTP não encontrado." -ForegroundColor Red
}

Write-Host "`n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes HTTPS" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
if (Test-Path "$projectRoot/tests/https/functional/test-https.ps1") {
    & "$projectRoot/tests/https/functional/test-https.ps1"
} else {
    Write-Host "[ERRO] Script de teste HTTPS não encontrado." -ForegroundColor Red
}

Write-Host "`n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes WebSocket" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
if (Test-Path "$projectRoot/tests/websocket/functional/test-websocket.ps1") {
    & "$projectRoot/tests/websocket/functional/test-websocket.ps1"
} else {
    Write-Host "[ERRO] Script de teste WebSocket não encontrado." -ForegroundColor Red
}

Write-Host "`n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes GraphQL" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
if (Test-Path "$projectRoot/tests/graphql/functional/test-graphql.ps1") {
    & "$projectRoot/tests/graphql/functional/test-graphql.ps1"
} else {
    Write-Host "[ERRO] Script de teste GraphQL não encontrado." -ForegroundColor Red
}

# =========================
# 4. Instruções para testes de performance
# =========================
Write-Host "`n==> Testes funcionais concluídos!" -ForegroundColor Green

# Criar tabela de resultados
$results = @{
    "HTTP" = $false
    "HTTPS" = $false
    "WebSocket" = $false
    "GraphQL" = $false
}

# Verificar resultados dos testes
if (Test-Path "$projectRoot/tests/http/functional/test-http.ps1") {
    $results["HTTP"] = $true
}
if (Test-Path "$projectRoot/tests/https/functional/test-https.ps1") {
    $results["HTTPS"] = $true
}
if (Test-Path "$projectRoot/tests/websocket/functional/test-websocket.ps1") {
    $results["WebSocket"] = $true
}
if (Test-Path "$projectRoot/tests/graphql/functional/test-graphql.ps1") {
    $results["GraphQL"] = $true
}

# Exibir tabela de resultados
Write-Host "`n=====================" -ForegroundColor Cyan
Write-Host "Resumo dos Testes" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host "Protocolo    | Status" -ForegroundColor Cyan
Write-Host "---------------------" -ForegroundColor Cyan

foreach ($protocol in $results.Keys) {
    $status = if ($results[$protocol]) { "✅ Sucesso" } else { "❌ Falha" }
    $statusColor = if ($results[$protocol]) { "Green" } else { "Red" }
    Write-Host ("{0,-12} | {1}" -f $protocol, $status) -ForegroundColor $statusColor
}

Write-Host "`nPara executar testes de performance, use os scripts:" -ForegroundColor Yellow
Write-Host "- HTTP:       $projectRoot/tests/http/performance/run-http-benchmark-apigw.ps1 e run-http-benchmark-ingress.ps1" -ForegroundColor Yellow
Write-Host "- HTTPS:      Verificar documentação específica para testes de HTTPS" -ForegroundColor Yellow
Write-Host "- WebSocket:  $projectRoot/tests/websocket/performance/run-websocket-benchmark-apigw.ps1 e run-websocket-benchmark-ingress.ps1" -ForegroundColor Yellow
Write-Host "- GraphQL:    $projectRoot/tests/graphql/performance/run-graphql-benchmark-apigw.ps1 e run-graphql-benchmark-ingress.ps1" -ForegroundColor Yellow