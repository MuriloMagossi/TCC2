# tests/graphql/functional/test-graphql-basic.ps1

# =========================
# Script para teste funcional básico de GraphQL
# Verifica consultas para API Gateway e Serviço Direto
# =========================

Write-Host "==> Iniciando teste funcional básico de GraphQL..." -ForegroundColor Cyan

# Diretório para resultados
$resultsDir = "tests/graphql/functional/results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}

# Função para testar consulta GraphQL
function Test-GraphQLQuery {
    param (
        [string]$Name,
        [string]$Service,
        [int]$Port,
        [int]$TargetPort,
        [string]$Namespace,
        [string]$Query = '{"query":"{ hello }"}'
    )
    
    Write-Host "`n> Testando consulta GraphQL para ${Name}..." -ForegroundColor Yellow
    
    # Iniciar port-forward
    Write-Host "  Iniciando port-forward para $Service..." -ForegroundColor Gray
    $portForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward $Service ${Port}:${TargetPort} -n $Namespace" -PassThru -NoNewWindow
    Start-Sleep -Seconds 3 # Aguardar conexão ser estabelecida
    
    $url = "http://localhost:${Port}/graphql"
    $success = $false
    $errorMsg = $null
    $responseData = $null
    $startTime = Get-Date
    
    try {
        # Preparar a requisição HTTP
        $webRequest = [System.Net.WebRequest]::Create($url)
        $webRequest.Method = "POST"
        $webRequest.ContentType = "application/json"
        $webRequest.Timeout = 5000 # 5 segundos
        
        # Enviar a consulta GraphQL
        $requestStream = $webRequest.GetRequestStream()
        $writer = New-Object System.IO.StreamWriter($requestStream)
        $writer.Write($Query)
        $writer.Close()
        $requestStream.Close()
        
        # Obter a resposta
        $webResponse = $webRequest.GetResponse()
        $responseStream = $webResponse.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $responseData = $reader.ReadToEnd()
        $reader.Close()
        $responseStream.Close()
        $webResponse.Close()
        
        # Verificar se a resposta contém o campo esperado
        if ($responseData -match '"hello":') {
            $success = $true
        } else {
            $errorMsg = "Resposta não contém o campo 'hello'"
        }
    } 
    catch {
        $success = $false
        $errorMsg = $_.Exception.Message
    }
    finally {
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
        Write-Host "  [OK] Consulta bem-sucedida em $([Math]::Round($duration, 0)) ms" -ForegroundColor Green
        Write-Host "  Resposta: $responseData" -ForegroundColor Gray
    } else {
        Write-Host "  [FALHA] Erro na consulta: $errorMsg ($([Math]::Round($duration, 0)) ms)" -ForegroundColor Red
        if ($responseData) {
            Write-Host "  Resposta: $responseData" -ForegroundColor Gray
        }
    }
    
    return @{
        Name = $Name
        Success = $success
        Error = $errorMsg
        Response = $responseData
        Duration = $duration
    }
}

# Testar consulta mais complexa
function Test-ComplexQuery {
    param (
        [string]$Name,
        [string]$Service,
        [int]$Port,
        [int]$TargetPort,
        [string]$Namespace
    )
    
    Write-Host "`n> Testando consulta complexa para ${Name}..." -ForegroundColor Yellow
    
    # Consulta mais elaborada (ajuste conforme seu schema GraphQL)
    $complexQuery = @"
{"query":"query { 
  __schema { 
    types { 
      name 
      kind 
      description 
    } 
  } 
}"}
"@
    
    $result = Test-GraphQLQuery -Name $Name -Service $Service -Port $Port -TargetPort $TargetPort -Namespace $Namespace -Query $complexQuery
    
    # Verificar se a resposta contém tipos do schema
    if ($result.Success -and $result.Response -match '"__schema"') {
        Write-Host "  [OK] Schema GraphQL recuperado com sucesso" -ForegroundColor Green
    } elseif ($result.Success) {
        $result.Success = $false
        $result.Error = "Resposta não contém informações do schema"
        Write-Host "  [FALHA] $($result.Error)" -ForegroundColor Red
    }
    
    return $result
}

# Testar API Gateway GraphQL
$apigwResult = Test-GraphQLQuery -Name "API Gateway GraphQL" -Service "svc/nginx-apigw-graphql" -Port 9601 -TargetPort 80 -Namespace "graphql"

# Testar Serviço GraphQL Direto
$serviceResult = Test-GraphQLQuery -Name "Serviço GraphQL Direto" -Service "svc/graphql-service" -Port 9701 -TargetPort 80 -Namespace "graphql"

# Se os testes básicos passaram, tentar consultas mais complexas
if ($apigwResult.Success -and $serviceResult.Success) {
    $apigwComplexResult = Test-ComplexQuery -Name "API Gateway GraphQL (Schema)" -Service "svc/nginx-apigw-graphql" -Port 9601 -TargetPort 80 -Namespace "graphql"
    $serviceComplexResult = Test-ComplexQuery -Name "Serviço GraphQL Direto (Schema)" -Service "svc/graphql-service" -Port 9701 -TargetPort 80 -Namespace "graphql"
    
    # Atualizar resultados combinados
    $apigwResult.Success = $apigwResult.Success -and $apigwComplexResult.Success
    $serviceResult.Success = $serviceResult.Success -and $serviceComplexResult.Success
    
    if (-not $apigwComplexResult.Success) {
        $apigwResult.Error = $apigwComplexResult.Error
    }
    
    if (-not $serviceComplexResult.Success) {
        $serviceResult.Error = $serviceComplexResult.Error
    }
}

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
    Write-Host "1. Verifique se o namespace 'graphql' existe: kubectl get ns"
    Write-Host "2. Verifique se os serviços estão rodando: kubectl get pods -n graphql"
    Write-Host "3. Verifique os logs dos serviços: kubectl logs -n graphql deploy/graphql-service"
    Write-Host "4. Verifique se o API Gateway está configurado: kubectl get ingress -n graphql"
}

Write-Host "`n==> Teste funcional concluído!" -ForegroundColor $(if ($allSuccess) { "Green" } else { "Yellow" }) 