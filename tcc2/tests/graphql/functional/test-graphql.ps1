# tests/graphql/functional/test-graphql.ps1

# =========================
# 1. Configuração de Port-Forward para teste direto (evita problemas de NodePort/Ingress)
# =========================
Write-Host "==> Iniciando port-forward para GraphQL..." -ForegroundColor Cyan

# Porta para API Gateway GraphQL
$apigwPortForward = 9701
# Iniciar port-forward para API Gateway
$apigwPortForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward svc/nginx-apigw-graphql $apigwPortForward`:80 -n graphql" -PassThru -NoNewWindow
Start-Sleep -Seconds 2 # Aguardar conexão ser estabelecida

# Porta para serviço GraphQL direto
$servicePortForward = 9700
# Iniciar port-forward para serviço
$servicePortForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward svc/graphql-echo $servicePortForward`:9000 -n graphql" -PassThru -NoNewWindow
Start-Sleep -Seconds 2 # Aguardar conexão ser estabelecida

# =========================
# 2. Testes
# =========================
Write-Host "==> Testando GraphQL via API Gateway (port-forward $apigwPortForward)..." -ForegroundColor Cyan

# Testar query hello 
try {
    $query = '{"query": "{ hello }"}'
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    $result = Invoke-WebRequest -Uri "http://localhost:$apigwPortForward/" -Method POST -Body $query -Headers $headers
    $content = $result.Content | ConvertFrom-Json
    
    if ($content.data.hello -eq "Hello from GraphQL!") {
        Write-Host "GraphQL Hello Query OK (API Gateway): $($content.data.hello)" -ForegroundColor Green
    } else {
        Write-Host "GraphQL Hello Query FALHOU (API Gateway): Resposta inesperada - $($content.data.hello)" -ForegroundColor Red
    }
} catch {
    Write-Host "GraphQL Hello Query FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}

# Testar query echo
try {
    $echo_message = "Testing GraphQL API Gateway"
    $query = '{"query": "{ echo(message: \"' + $echo_message + '\") { message timestamp } }"}'
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    $result = Invoke-WebRequest -Uri "http://localhost:$apigwPortForward/" -Method POST -Body $query -Headers $headers
    $content = $result.Content | ConvertFrom-Json
    
    if ($content.data.echo.message -eq $echo_message) {
        Write-Host "GraphQL Echo Query OK (API Gateway): $($content.data.echo.message)" -ForegroundColor Green
        Write-Host "Timestamp: $($content.data.echo.timestamp)" -ForegroundColor Gray
    } else {
        Write-Host "GraphQL Echo Query FALHOU (API Gateway): Resposta inesperada - $($content.data.echo.message)" -ForegroundColor Red
    }
} catch {
    Write-Host "GraphQL Echo Query FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "==> Testando GraphQL diretamente via Serviço (port-forward $servicePortForward)..." -ForegroundColor Cyan

# Testar query hello
try {
    $query = '{"query": "{ hello }"}'
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    $result = Invoke-WebRequest -Uri "http://localhost:$servicePortForward/" -Method POST -Body $query -Headers $headers
    $content = $result.Content | ConvertFrom-Json
    
    if ($content.data.hello -eq "Hello from GraphQL!") {
        Write-Host "GraphQL Hello Query OK (Serviço direto): $($content.data.hello)" -ForegroundColor Green
    } else {
        Write-Host "GraphQL Hello Query FALHOU (Serviço direto): Resposta inesperada - $($content.data.hello)" -ForegroundColor Red
    }
} catch {
    Write-Host "GraphQL Hello Query FALHOU (Serviço direto): $($_.Exception.Message)" -ForegroundColor Red
}

# Testar query echo
try {
    $echo_message = "Testing GraphQL Service"
    $query = '{"query": "{ echo(message: \"' + $echo_message + '\") { message timestamp } }"}'
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    $result = Invoke-WebRequest -Uri "http://localhost:$servicePortForward/" -Method POST -Body $query -Headers $headers
    $content = $result.Content | ConvertFrom-Json
    
    if ($content.data.echo.message -eq $echo_message) {
        Write-Host "GraphQL Echo Query OK (Serviço direto): $($content.data.echo.message)" -ForegroundColor Green
        Write-Host "Timestamp: $($content.data.echo.timestamp)" -ForegroundColor Gray
    } else {
        Write-Host "GraphQL Echo Query FALHOU (Serviço direto): Resposta inesperada - $($content.data.echo.message)" -ForegroundColor Red
    }
} catch {
    Write-Host "GraphQL Echo Query FALHOU (Serviço direto): $($_.Exception.Message)" -ForegroundColor Red
}

# =========================
# 3. Limpeza - Finalizar processos de port-forward
# =========================
Write-Host "==> Finalizando port-forwards..." -ForegroundColor Cyan
if ($apigwPortForwardProcess) {
    try { 
        Stop-Process -Id $apigwPortForwardProcess.Id -Force -ErrorAction SilentlyContinue 
        Write-Host "Port-forward API Gateway finalizado" -ForegroundColor Gray
    } catch {}
}

if ($servicePortForwardProcess) {
    try { 
        Stop-Process -Id $servicePortForwardProcess.Id -Force -ErrorAction SilentlyContinue 
        Write-Host "Port-forward Serviço finalizado" -ForegroundColor Gray
    } catch {}
}

Write-Host "`nPara testar manualmente com port-forwards:" -ForegroundColor Yellow
Write-Host "1. kubectl port-forward svc/nginx-apigw-graphql 9701:80 -n graphql" -ForegroundColor Yellow
Write-Host "2. kubectl port-forward svc/graphql-echo 9700:9000 -n graphql" -ForegroundColor Yellow
Write-Host "3. curl -X POST -H 'Content-Type: application/json' -d '{\"query\": \"{hello}\"}' http://localhost:9700/" -ForegroundColor Yellow 