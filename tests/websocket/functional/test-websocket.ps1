# tests/websocket/functional/test-websocket.ps1

# =========================
# 1. Configuração de Port-Forward para teste direto (evita problemas de NodePort/Ingress)
# =========================
Write-Host "==> Iniciando port-forward para WebSocket..." -ForegroundColor Cyan

# Porta para API Gateway WebSocket
$apigwPortForward = 9801
# Iniciar port-forward para API Gateway
$apigwPortForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward svc/nginx-apigw-ws $apigwPortForward`:80 -n websocket" -PassThru -NoNewWindow
Start-Sleep -Seconds 2 # Aguardar conexão ser estabelecida

# Porta para serviço WebSocket direto
$servicePortForward = 9901
# Iniciar port-forward para serviço
$servicePortForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward svc/websocket-echo $servicePortForward`:9000 -n websocket" -PassThru -NoNewWindow
Start-Sleep -Seconds 2 # Aguardar conexão ser estabelecida

# =========================
# 2. Testes
# =========================
Write-Host "==> Testando WebSocket via API Gateway (port-forward $apigwPortForward)..." -ForegroundColor Cyan

try {
    # Testar usando netcat (precisa estar instalado)
    Write-Host "Testando conexão WebSocket no API Gateway..."
    $testMessage = "Hello WebSocket API Gateway"

    # Usando PowerShell 7+
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $ct = New-Object System.Threading.CancellationToken
        $conn = $ws.ConnectAsync("ws://localhost:$apigwPortForward/", $ct)
        $conn.Wait()

        if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            Write-Host "WebSocket conectado ao API Gateway com sucesso!" -ForegroundColor Green
            
            # Enviar mensagem
            $sendBuffer = [System.Text.Encoding]::UTF8.GetBytes($testMessage)
            $ws.SendAsync($sendBuffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
            
            # Receber resposta
            $receiveBuffer = [byte[]]::new(1024)
            $receive = $ws.ReceiveAsync($receiveBuffer, $ct)
            $receive.Wait()
            
            $response = [System.Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $receive.Result.Count)
            Write-Host "WebSocket OK (API Gateway): $response" -ForegroundColor Green
            
            # Fechar conexão
            $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Test complete", $ct).Wait()
        } else {
            Write-Host "WebSocket FALHOU (API Gateway): Não foi possível estabelecer conexão" -ForegroundColor Red
        }
    } else {
        Write-Host "PowerShell 7+ é requerido para o teste de WebSocket nativo" -ForegroundColor Yellow
        Write-Host "Pulando teste de WebSocket para API Gateway" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WebSocket FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "==> Testando WebSocket diretamente via Serviço (port-forward $servicePortForward)..." -ForegroundColor Cyan

try {
    # Usando PowerShell 7+
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $ct = New-Object System.Threading.CancellationToken
        
        $conn = $ws.ConnectAsync("ws://localhost:$servicePortForward/", $ct)
        $conn.Wait()

        if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            Write-Host "WebSocket conectado ao Serviço direto com sucesso!" -ForegroundColor Green
            
            # Enviar mensagem
            $testMessage = "Hello WebSocket Service"
            $sendBuffer = [System.Text.Encoding]::UTF8.GetBytes($testMessage)
            $ws.SendAsync($sendBuffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
            
            # Receber resposta
            $receiveBuffer = [byte[]]::new(1024)
            $receive = $ws.ReceiveAsync($receiveBuffer, $ct)
            $receive.Wait()
            
            $response = [System.Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $receive.Result.Count)
            Write-Host "WebSocket OK (Serviço direto): $response" -ForegroundColor Green
            
            # Fechar conexão
            $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Test complete", $ct).Wait()
        } else {
            Write-Host "WebSocket FALHOU (Serviço direto): Não foi possível estabelecer conexão" -ForegroundColor Red
        }
    } else {
        Write-Host "PowerShell 7+ é requerido para o teste de WebSocket nativo" -ForegroundColor Yellow
        Write-Host "Pulando teste de WebSocket para Serviço direto" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WebSocket FALHOU (Serviço direto): $($_.Exception.Message)" -ForegroundColor Red
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

# Alternativa para teste manual
Write-Host "`nPara testar manualmente com port-forwards:" -ForegroundColor Yellow
Write-Host "1. kubectl port-forward svc/nginx-apigw-ws 9801:80 -n websocket" -ForegroundColor Yellow
Write-Host "2. kubectl port-forward svc/websocket-echo 9901:9000 -n websocket" -ForegroundColor Yellow
Write-Host "3. Usar websocat: websocat ws://localhost:9901/" -ForegroundColor Yellow 