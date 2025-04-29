# tests/tcp/functional/test-tcp.ps1

# Detectar NodePort do API Gateway TCP
$apigwPort = kubectl get svc nginx-apigw-tcp -n tcp -o jsonpath="{.spec.ports[0].nodePort}"
Write-Host "==> Testando TCP via API Gateway (porta $apigwPort)..." -ForegroundColor Cyan
try {
    $client = New-Object System.Net.Sockets.TcpClient("localhost", $apigwPort)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    $writer.WriteLine("teste-api-gateway")
    $writer.Flush()
    Start-Sleep -Milliseconds 500
    $response = $reader.ReadLine()
    if ($response -eq "teste-api-gateway") {
        Write-Host "TCP OK (API Gateway): $response" -ForegroundColor Green
    } else {
        Write-Host "TCP FALHOU (API Gateway): resposta inesperada: $response" -ForegroundColor Red
    }
    $writer.Close()
    $reader.Close()
    $client.Close()
} catch {
    Write-Host "TCP FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}

# Detectar NodePort do Ingress Controller para TCP
Write-Host "==> Descobrindo NodePort do Ingress Controller para TCP..."
$nodePort = kubectl get svc ingress-nginx-tcp -n ingress-nginx -o jsonpath="{.spec.ports[0].nodePort}"
Write-Host "NodePort detectado: $nodePort" -ForegroundColor Yellow

$ingressPort = 30901

Write-Host "==> Testando TCP via Ingress Controller (porta $ingressPort)..." -ForegroundColor Cyan
try {
    $client = New-Object System.Net.Sockets.TcpClient("localhost", $ingressPort)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    $writer.WriteLine("teste-ingress")
    $writer.Flush()
    Start-Sleep -Milliseconds 500
    $response = $reader.ReadLine()
    if ($response -eq "teste-ingress") {
        Write-Host "TCP OK (Ingress Controller): $response" -ForegroundColor Green
    } else {
        Write-Host "TCP FALHOU (Ingress Controller): resposta inesperada: $response" -ForegroundColor Red
    }
    $writer.Close()
    $reader.Close()
    $client.Close()
} catch {
    Write-Host "TCP FALHOU (Ingress Controller): $($_.Exception.Message)" -ForegroundColor Red
} 