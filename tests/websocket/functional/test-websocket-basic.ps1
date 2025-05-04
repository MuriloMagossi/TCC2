# tests/websocket/functional/test-websocket-basic.ps1

# =========================
# Script para teste funcional básico de WebSocket
# Verifica conexões para API Gateway e Serviço Direto
# =========================

Write-Host "==> Iniciando teste funcional básico de WebSocket..." -ForegroundColor Cyan

# Diretório para resultados
$resultsDir = "tests/websocket/functional/results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}

# Função para testar conexão WebSocket
function Test-WebSocketConnection {
    param (
        [string]$Name,
        [string]$Service,
        [int]$Port,
        [int]$TargetPort,
        [string]$Namespace
    )
    
    Write-Host "`n> Testando conexão WebSocket para ${Name}..." -ForegroundColor Yellow
    
    # Iniciar port-forward
    Write-Host "  Iniciando port-forward para $Service..." -ForegroundColor Gray
    $portForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward $Service ${Port}:${TargetPort} -n $Namespace" -PassThru -NoNewWindow
    Start-Sleep -Seconds 3 # Aguardar conexão ser estabelecida
    
    $success = $false
    $errorMsg = $null
    $startTime = Get-Date
    
    try {
        # Usar System.Net.Sockets para testar a conexão TCP básica
        $client = New-Object System.Net.Sockets.TcpClient
        $connectionTask = $client.ConnectAsync("localhost", $Port)
        
        # Esperar por até 5 segundos
        if ($connectionTask.Wait(5000)) {
            $success = $client.Connected
        } else {
            $errorMsg = "Timeout na conexão"
        }
        
        if ($success) {
            # Enviar um simples HTTP GET com Upgrade para WebSocket
            $stream = $client.GetStream()
            $writer = New-Object System.IO.StreamWriter($stream)
            $writer.WriteLine("GET / HTTP/1.1")
            $writer.WriteLine("Host: localhost:$Port")
            $writer.WriteLine("Connection: Upgrade")
            $writer.WriteLine("Upgrade: websocket")
            $writer.WriteLine("Sec-WebSocket-Version: 13")
            $writer.WriteLine("Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==")
            $writer.WriteLine("")
            $writer.Flush()
            
            # Tentar ler a resposta
            $responseAvailable = $false
            
            if ($stream.DataAvailable -or $stream.Socket.Poll(3000, [System.Net.Sockets.SelectMode]::SelectRead)) {
                $buffer = New-Object byte[] 1024
                $bytesRead = $stream.Read($buffer, 0, 1024)
                
                if ($bytesRead -gt 0) {
                    $response = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
                    $responseAvailable = $true
                    
                    # Verificar se contém um header de Upgrade
                    if ($response -match "HTTP/1.1 101") {
                        Write-Host "    Resposta de upgrade para WebSocket recebida" -ForegroundColor Green
                    } else {
                        Write-Host "    Resposta recebida, mas não é um upgrade WebSocket" -ForegroundColor Yellow
                        Write-Host "    $($response.Split("`n")[0])" -ForegroundColor Gray
                    }
                }
            }
            
            if (-not $responseAvailable) {
                Write-Host "    Conexão TCP estabelecida, mas sem resposta HTTP" -ForegroundColor Yellow
            }
        }
    } 
    catch {
        $success = $false
        $errorMsg = $_.Exception.Message
    }
    finally {
        # Fechar a conexão
        if ($client -ne $null) {
            try { $client.Close() } catch {}
            try { $client.Dispose() } catch {}
        }
        
        # Finalizar port-forward
        if ($portForwardProcess -and -not $portForwardProcess.HasExited) {
            Stop-Process -Id $portForwardProcess.Id -Force -ErrorAction SilentlyContinue
            Write-Host "  Port-forward finalizado" -ForegroundColor Gray
        }
    }
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMilliseconds
    
    # Exibir resultado
    if ($success) {
        Write-Host "  [OK] Conexão bem-sucedida em $([Math]::Round($duration, 0)) ms" -ForegroundColor Green
    } else {
        Write-Host "  [FALHA] Erro na conexão: $errorMsg ($([Math]::Round($duration, 0)) ms)" -ForegroundColor Red
    }
    
    return @{
        Name = $Name
        Success = $success
        Error = $errorMsg
        Duration = $duration
    }
}

# Testar API Gateway WebSocket
$apigwResult = Test-WebSocketConnection -Name "API Gateway WebSocket" -Service "svc/nginx-apigw-ws" -Port 9801 -TargetPort 80 -Namespace "websocket"

# Testar Serviço WebSocket Direto
$serviceResult = Test-WebSocketConnection -Name "Serviço WebSocket Direto" -Service "svc/websocket-echo" -Port 9901 -TargetPort 9000 -Namespace "websocket"

# Resumo dos resultados
Write-Host "`n==> RESUMO DOS TESTES" -ForegroundColor Cyan
Write-Host "=============================="

$allSuccess = $apigwResult.Success -and $serviceResult.Success

Write-Host "API Gateway: $(if ($apigwResult.Success) { "SUCESSO" } else { "FALHA" })"
Write-Host "Serviço Direto: $(if ($serviceResult.Success) { "SUCESSO" } else { "FALHA" })"
Write-Host "Resultado geral: $(if ($allSuccess) { "TODOS FUNCIONANDO" } else { "PROBLEMAS DETECTADOS" })" -ForegroundColor $(if ($allSuccess) { "Green" } else { "Red" })

if (-not $allSuccess) {
    Write-Host "`nDETALHES DOS PROBLEMAS:" -ForegroundColor Yellow
    if (-not $apigwResult.Success) {
        Write-Host "- API Gateway: $($apigwResult.Error)" -ForegroundColor Red
    }
    if (-not $serviceResult.Success) {
        Write-Host "- Serviço Direto: $($serviceResult.Error)" -ForegroundColor Red
    }
    
    Write-Host "`nPOSSÍVEIS SOLUÇÕES:" -ForegroundColor Yellow
    Write-Host "1. Verifique se o namespace 'websocket' existe: kubectl get ns"
    Write-Host "2. Verifique se os serviços estão rodando: kubectl get pods -n websocket"
    Write-Host "3. Verifique os logs dos serviços: kubectl logs -n websocket deploy/websocket-echo"
    Write-Host "4. Verifique se o API Gateway está configurado: kubectl get ingress -n websocket"
}

Write-Host "`n==> Teste funcional concluído!" -ForegroundColor $(if ($allSuccess) { "Green" } else { "Yellow" }) 