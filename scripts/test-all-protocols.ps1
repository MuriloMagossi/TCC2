# scripts/test-all-protocols.ps1

# =========================
# 1. Aplicação dos manifests
# =========================
Write-Host "==> Aplicando HTTP..." -ForegroundColor Cyan
kubectl apply -n http -f manifests/http/app/
Write-Host "==> Aplicando Ingress Controller HTTP..." -ForegroundColor Cyan
kubectl apply -f manifests/http/nginx-ingress/
Write-Host "==> Aplicando API Gateway HTTP..." -ForegroundColor Cyan
kubectl apply -n http -f manifests/http/nginx-apigw/

Write-Host "==> Aplicando HTTPS..." -ForegroundColor Cyan
kubectl apply -f manifests/https/nginx-apigw/tls-secret.yaml
kubectl apply -n https -f manifests/https/app/
Write-Host "==> Aplicando API Gateway HTTPS..." -ForegroundColor Cyan
kubectl apply -n https -f manifests/https/nginx-apigw/
Write-Host "==> Aplicando Ingress Controller HTTPS..." -ForegroundColor Cyan
kubectl apply -f manifests/https/nginx-ingress/

Write-Host "==> Aplicando ConfigMap tcp-services unificado..." -ForegroundColor Cyan
if (Test-Path manifests/tcp-services.yaml) {
    kubectl apply -f manifests/tcp-services.yaml
} else {
    Write-Host "[INFO] Arquivo tcp-services.yaml não encontrado. Pulando..." -ForegroundColor Yellow
}

Write-Host "==> Aplicando serviços do Ingress Controller..." -ForegroundColor Cyan
if (Test-Path manifests/ingress-services.yaml) {
    kubectl apply -f manifests/ingress-services.yaml
} else {
    Write-Host "[INFO] Arquivo ingress-services.yaml não encontrado. Pulando..." -ForegroundColor Yellow
}

Write-Host "==> Aplicando WebSocket..." -ForegroundColor Cyan
kubectl apply -n websocket -f manifests/websocket/app/
Write-Host "==> Aplicando API Gateway WebSocket..." -ForegroundColor Cyan
kubectl apply -n websocket -f manifests/websocket/nginx-apigw/
Write-Host "==> Aplicando Ingress Controller WebSocket..." -ForegroundColor Cyan
kubectl apply -f manifests/websocket/nginx-ingress/

Write-Host "==> Aplicando GraphQL..." -ForegroundColor Cyan
kubectl apply -n graphql -f manifests/graphql/app/
Write-Host "==> Aplicando API Gateway GraphQL..." -ForegroundColor Cyan
kubectl apply -n graphql -f manifests/graphql/nginx-apigw/
Write-Host "==> Aplicando Ingress Controller GraphQL..." -ForegroundColor Cyan
kubectl apply -f manifests/graphql/nginx-ingress/

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
if (Test-Path tests/http/functional/test-http.ps1) {
    & tests/http/functional/test-http.ps1
} else {
    Write-Host "[ERRO] Script de teste HTTP não encontrado." -ForegroundColor Red
}

Write-Host "`n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes HTTPS" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
if (Test-Path tests/https/functional/test-https.ps1) {
    & tests/https/functional/test-https.ps1
} else {
    Write-Host "[ERRO] Script de teste HTTPS não encontrado." -ForegroundColor Red
}

Write-Host "`n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes WebSocket" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
if (Test-Path tests/websocket/functional/test-websocket.ps1) {
    & tests/websocket/functional/test-websocket.ps1
} else {
    Write-Host "[ERRO] Script de teste WebSocket não encontrado." -ForegroundColor Red
}

Write-Host "`n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes GraphQL" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
if (Test-Path tests/graphql/functional/test-graphql.ps1) {
    & tests/graphql/functional/test-graphql.ps1
} else {
    Write-Host "[ERRO] Script de teste GraphQL não encontrado." -ForegroundColor Red
}

# =========================
# 4. Instruções para testes de performance
# =========================
Write-Host "`n==> Testes funcionais concluídos!" -ForegroundColor Green
Write-Host "`nPara executar testes de performance, use os scripts:" -ForegroundColor Yellow
Write-Host "- HTTP:       ./tests/http/performance/run-http-benchmark-apigw.ps1 e run-http-benchmark-ingress.ps1" -ForegroundColor Yellow
Write-Host "- HTTPS:      Verificar documentação específica para testes de HTTPS" -ForegroundColor Yellow
Write-Host "- WebSocket:  ./tests/websocket/performance/run-websocket-benchmark-apigw.ps1 e run-websocket-benchmark-ingress.ps1" -ForegroundColor Yellow
Write-Host "- GraphQL:    ./tests/graphql/performance/run-graphql-benchmark-apigw.ps1 e run-graphql-benchmark-ingress.ps1" -ForegroundColor Yellow