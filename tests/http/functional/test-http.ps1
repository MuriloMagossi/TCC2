# tests/http/functional/test-http.ps1

# Detectar NodePort do API Gateway HTTP
$apigwPort = kubectl get svc nginx-apigw -n http -o jsonpath="{.spec.ports[0].nodePort}"
Write-Host "==> Testando HTTP via API Gateway (porta $apigwPort)..." -ForegroundColor Cyan
try {
    $result = Invoke-WebRequest -Uri "http://localhost:$apigwPort/"
    Write-Host "HTTP OK (API Gateway): $($result.Content)" -ForegroundColor Green
} catch {
    Write-Host "HTTP FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}

# Usar sempre a porta 8080 para o Ingress Controller HTTP
$ingressPort = 8080
Write-Host "==> Testando HTTP via Ingress Controller (porta $ingressPort)..." -ForegroundColor Cyan
try {
    $result = Invoke-WebRequest -Uri "http://localhost:$ingressPort/" -Headers @{Host="http.localtest.me"}
    Write-Host "HTTP OK (Ingress Controller): $($result.Content)" -ForegroundColor Green
} catch {
    Write-Host "HTTP FALHOU (Ingress Controller): $($_.Exception.Message)" -ForegroundColor Red
} 