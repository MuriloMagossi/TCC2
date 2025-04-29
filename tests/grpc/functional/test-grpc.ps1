# tests/grpc/functional/test-grpc.ps1

# Detectar NodePort do API Gateway gRPC
$apigwPort = kubectl get svc nginx-apigw-grpc -n grpc -o jsonpath="{.spec.ports[0].nodePort}"
Write-Host "==> Testando gRPC via API Gateway (porta $apigwPort)..." -ForegroundColor Cyan
try {
    docker run --rm --network=host fullstorydev/grpcurl -plaintext localhost:$apigwPort list
    Write-Host "gRPC OK (API Gateway): grpcurl respondeu com lista de serviços" -ForegroundColor Green
} catch {
    Write-Host "gRPC FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}

# Usar sempre a porta 30900 para o Ingress Controller gRPC
$ingressPort = 30900
Write-Host "==> Testando gRPC via Ingress Controller (porta $ingressPort)..." -ForegroundColor Cyan
try {
    docker run --rm --network=host fullstorydev/grpcurl -plaintext localhost:$ingressPort list
    Write-Host "gRPC OK (Ingress Controller): grpcurl respondeu com lista de serviços" -ForegroundColor Green
} catch {
    Write-Host "gRPC FALHOU (Ingress Controller): $($_.Exception.Message)" -ForegroundColor Red
} 