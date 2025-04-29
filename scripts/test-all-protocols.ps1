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

Write-Host "==> Aplicando gRPC..." -ForegroundColor Cyan
kubectl apply -n grpc -f manifests/grpc/app/
Write-Host "==> Aplicando API Gateway gRPC..." -ForegroundColor Cyan
kubectl apply -n grpc -f manifests/grpc/nginx-apigw/

Write-Host "==> Aplicando TCP..." -ForegroundColor Cyan
kubectl apply -n tcp -f manifests/tcp/app/
Write-Host "==> Aplicando API Gateway TCP..." -ForegroundColor Cyan
kubectl apply -n tcp -f manifests/tcp/nginx-apigw/
Write-Host "==> Aplicando Ingress Controller TCP..." -ForegroundColor Cyan
kubectl apply -f manifests/tcp/nginx-ingress/

# =========================
# 2. Espera dos pods ficarem prontos
# =========================
Write-Host "==> Aguardando pods ficarem prontos..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod -l app=http-echo -n http --timeout=60s
kubectl wait --for=condition=Ready pod -l app=grpc-echo -n grpc --timeout=60s
kubectl wait --for=condition=Ready pod -l app=tcp-echo -n tcp --timeout=60s
kubectl wait --for=condition=Ready pod -l app=https-echo -n https --timeout=60s

# =========================
# 3. Testes funcionais por protocolo
# =========================
Write-Host "\n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes HTTP" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
& tests/http/functional/test-http.ps1

Write-Host "\n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes HTTPS" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
& tests/https/functional/test-https.ps1

Write-Host "\n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes gRPC" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
& tests/grpc/functional/test-grpc.ps1

Write-Host "\n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes TCP" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan
& tests/tcp/functional/test-tcp.ps1