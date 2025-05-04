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

# Teste simplificado - apenas verificar se a conexão é possível
Write-Host "==> Verificando conexão TCP básica na porta $nodePort..." -ForegroundColor Cyan
try {
    $client = New-Object System.Net.Sockets.TcpClient("localhost", $nodePort)
    if ($client.Connected) {
        Write-Host "CONEXÃO OK: Conseguiu conectar à porta $nodePort" -ForegroundColor Green
        $client.Close()
    } else {
        Write-Host "CONEXÃO FALHOU: Não conseguiu conectar à porta $nodePort" -ForegroundColor Red
    }
} catch {
    Write-Host "CONEXÃO FALHOU: $($_.Exception.Message)" -ForegroundColor Red
}

# Teste completo com envio/recebimento
Write-Host "==> Testando TCP via Ingress Controller (porta $nodePort)..." -ForegroundColor Cyan
try {
    $client = New-Object System.Net.Sockets.TcpClient("localhost", $nodePort)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    
    # Debug - verificar se consegue enviar dados
    Write-Host "DEBUG: Enviando mensagem teste-ingress..." -ForegroundColor Yellow
    $writer.WriteLine("teste-ingress")
    $writer.Flush()
    
    # Esperar mais tempo pela resposta
    Write-Host "DEBUG: Aguardando resposta (2 segundos)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    if ($stream.DataAvailable) {
        Write-Host "DEBUG: Dados disponíveis para leitura" -ForegroundColor Yellow
        $response = $reader.ReadLine()
        Write-Host "DEBUG: Resposta recebida: '$response'" -ForegroundColor Yellow
        
        if ($response -eq "teste-ingress") {
            Write-Host "TCP OK (Ingress Controller): $response" -ForegroundColor Green
        } else {
            Write-Host "TCP FALHOU (Ingress Controller): resposta inesperada: $response" -ForegroundColor Red
        }
    } else {
        Write-Host "DEBUG: Não há dados disponíveis para leitura após 2 segundos" -ForegroundColor Yellow
        Write-Host "TCP FALHOU (Ingress Controller): sem resposta do servidor" -ForegroundColor Red
    }
    
    $writer.Close()
    $reader.Close()
    $client.Close()
} catch {
    Write-Host "TCP FALHOU (Ingress Controller): $($_.Exception.Message)" -ForegroundColor Red
} 