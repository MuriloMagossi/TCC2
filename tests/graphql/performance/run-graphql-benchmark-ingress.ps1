# tests/graphql/performance/run-graphql-benchmark-ingress.ps1

# Parâmetros do teste
$queries = 200
$concurrentClients = 10
$duration = 30 # segundos

# Diretório e arquivo para salvar métricas do Docker (usar caminho absoluto)
$resultsDir = Join-Path $PSScriptRoot ".\results" | Resolve-Path | Select-Object -ExpandProperty Path
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}
$dockerStatsFile = Join-Path $resultsDir "docker-stats-graphql-ingress.csv"
$dockerStatsHeader = "Name,CPU %,Mem Usage / Limit,Net I/O,Block I/O,Timestamp"
Set-Content -Path $dockerStatsFile -Value $dockerStatsHeader

# Obter o endereço IP do ingress controller
Write-Host "==> Obtendo endereço IP do ingress controller..." -ForegroundColor Cyan

# Para Kind, usamos localhost com a porta mapeada no kind-config
$ingressIP = "localhost:8080"
Write-Host "Ingress controller encontrado em: $ingressIP" -ForegroundColor Green

Write-Host "==> Executando benchmark GraphQL para Ingress Controller..." -ForegroundColor Cyan

# Configurar URL e payload da consulta
$url = "http://$ingressIP/graphql"
$graphqlQuery = '{"query":"{ hello }"}'

# Iniciar coleta de métricas Docker como um job em paralelo
Write-Host "==> Iniciando coleta de métricas Docker durante o teste..." -ForegroundColor Cyan
$collectDockerMetricsJob = Start-Job -ScriptBlock {
    param($dockerStatsFile, $duration)
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($duration + 5) # Adicionar 5 segundos para garantir que cobre todo o teste
    while ((Get-Date) -lt $endTime) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $stats = docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}"
        $stats | ForEach-Object { "$_,$timestamp" } | Add-Content -Path $dockerStatsFile
        Start-Sleep -Milliseconds 500
    }
} -ArgumentList $dockerStatsFile, $duration

# Função para executar consultas GraphQL concorrentes
function Invoke-ConcurrentGraphQLQueries {
    param (
        [string]$Url,
        [string]$Query,
        [int]$NumQueries,
        [int]$ConcurrentClients,
        [int]$DurationSec
    )
    
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($DurationSec)
    $successCount = 0
    $failureCount = 0
    $responseTimes = New-Object System.Collections.ArrayList
    
    # Calcular número de consultas por thread
    $queriesPerClient = [Math]::Ceiling($NumQueries / $ConcurrentClients)
    
    # Criar trabalhos concorrentes
    $jobs = @()
    
    for ($i = 0; $i -lt $ConcurrentClients; $i++) {
        $startQuery = $i * $queriesPerClient
        $endQuery = [Math]::Min(($i + 1) * $queriesPerClient, $NumQueries)
        $queryCount = $endQuery - $startQuery
        
        if ($queryCount -le 0) {
            continue
        }
        
        $job = Start-Job -ScriptBlock {
            param($url, $query, $queryCount, $maxDuration)
            
            $results = @{
                SuccessCount = 0
                FailureCount = 0
                ResponseTimes = @()
            }
            
            $endTime = (Get-Date).AddSeconds($maxDuration)
            
            for ($i = 1; $i -le $queryCount; $i++) {
                # Verificar se ultrapassou o tempo máximo
                if ((Get-Date) -gt $endTime) {
                    break
                }
                
                try {
                    $startQuery = Get-Date
                    
                    # Configurar requisição HTTP
                    $webRequest = [System.Net.HttpWebRequest]::Create($url)
                    $webRequest.Method = "POST"
                    $webRequest.ContentType = "application/json"
                    $webRequest.Accept = "application/json"
                    $webRequest.Timeout = 30000
                    $webRequest.ReadWriteTimeout = 30000
                    $webRequest.KeepAlive = $true
                    $webRequest.ProtocolVersion = [System.Net.HttpVersion]::Version11
                    $webRequest.ServicePoint.Expect100Continue = $false
                    $webRequest.ServicePoint.UseNagleAlgorithm = $false
                    $webRequest.ServicePoint.ConnectionLimit = 100
                    $webRequest.Host = "graphql.localtest.me"
                    
                    # Enviar dados da consulta GraphQL
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($query)
                    $webRequest.ContentLength = $buffer.Length
                    $requestStream = $webRequest.GetRequestStream()
                    $requestStream.Write($buffer, 0, $buffer.Length)
                    $requestStream.Close()
                    
                    # Obter resposta
                    $response = $webRequest.GetResponse()
                    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
                    $responseContent = $reader.ReadToEnd()
                    $reader.Close()
                    $response.Close()
                    
                    $endQuery = Get-Date
                    $duration = ($endQuery - $startQuery).TotalMilliseconds
                    
                    # Verificar se a resposta contém o campo data
                    if ($responseContent -match '"data"') {
                        $results.SuccessCount++
                        $results.ResponseTimes += $duration
                    } else {
                        $results.FailureCount++
                    }
                }
                catch {
                    $results.FailureCount++
                }
            }
            
            return $results
        } -ArgumentList $Url, $Query, $queryCount, $DurationSec
        
        $jobs += $job
    }
    
    # Aguardar todos os jobs
    Write-Host "Executando $NumQueries consultas com $ConcurrentClients clientes concorrentes..." -ForegroundColor Yellow
    $jobs | Wait-Job | Out-Null
    
    # Processar resultados
    foreach ($job in $jobs) {
        $result = Receive-Job -Job $job
        $successCount += $result.SuccessCount
        $failureCount += $result.FailureCount
        foreach ($time in $result.ResponseTimes) {
            [void]$responseTimes.Add($time)
        }
    }
    
    # Limpar jobs
    $jobs | Remove-Job
    
    $actualEndTime = Get-Date
    $actualDuration = ($actualEndTime - $startTime).TotalSeconds
    $queriesPerSecond = if ($actualDuration -gt 0) { $successCount / $actualDuration } else { 0 }
    
    # Calcular estatísticas de latência
    $avgLatency = 0
    $p95Latency = 0
    $p99Latency = 0
    
    if ($responseTimes.Count -gt 0) {
        $avgLatency = ($responseTimes | Measure-Object -Average).Average
        $sortedTimes = $responseTimes | Sort-Object
        
        $p95Index = [Math]::Floor($sortedTimes.Count * 0.95)
        $p99Index = [Math]::Floor($sortedTimes.Count * 0.99)
        
        $p95Latency = if ($p95Index -lt $sortedTimes.Count) { $sortedTimes[$p95Index] } else { 0 }
        $p99Latency = if ($p99Index -lt $sortedTimes.Count) { $sortedTimes[$p99Index] } else { 0 }
    }
    
    # Total de consultas realmente realizadas
    $totalExecuted = $successCount + $failureCount
    $successRate = if ($totalExecuted -gt 0) { ($successCount / $totalExecuted) * 100 } else { 0 }
    
    return @{
        TotalExecuted = $totalExecuted
        SuccessCount = $successCount
        FailureCount = $failureCount
        SuccessRate = $successRate
        Duration = $actualDuration
        QueriesPerSecond = $queriesPerSecond
        AvgLatency = $avgLatency
        P95Latency = $p95Latency
        P99Latency = $p99Latency
        ResponseTimes = $responseTimes
    }
}

# Executar o teste principal
$testResult = Invoke-ConcurrentGraphQLQueries -Url $url -Query $graphqlQuery -NumQueries $queries -ConcurrentClients $concurrentClients -DurationSec $duration

# Formatar resultado em formato similar ao do hey para HTTP
$histogramBuckets = 10
$sortedTimes = $testResult.ResponseTimes | Sort-Object
if ($sortedTimes.Count -gt 0) {
    $minTime = ($sortedTimes | Measure-Object -Minimum).Minimum
    $maxTime = ($sortedTimes | Measure-Object -Maximum).Maximum
    $bucketSize = if ($maxTime -gt $minTime) { ($maxTime - $minTime) / $histogramBuckets } else { 1 }
    $buckets = @(0) * $histogramBuckets
    
    foreach ($time in $sortedTimes) {
        $bucketIndex = if ($maxTime -gt $minTime) {
            [Math]::Min([Math]::Floor(($time - $minTime) / $bucketSize), $histogramBuckets - 1)
        } else {
            0
        }
        $buckets[$bucketIndex]++
    }
    
    # Encontrar o bucket com mais elementos para normalização
    $maxBucketCount = ($buckets | Measure-Object -Maximum).Maximum
    
    # Criar histograma
    $histogramStr = "Response time histogram (ms):`n"
    for ($i = 0; $i -lt $histogramBuckets; $i++) {
        $bucketStart = ($minTime + ($i * $bucketSize)) / 1000  # convertendo para segundos
        $bucketEnd = ($minTime + (($i + 1) * $bucketSize)) / 1000
        $barLength = if ($maxBucketCount -gt 0) { [Math]::Round(($buckets[$i] / $maxBucketCount) * 40) } else { 0 }
        $bar = if ($barLength -gt 0) { "".PadRight($barLength, "#") } else { "" }
        $histogramStr += "  $([Math]::Round($bucketStart, 4)) - $([Math]::Round($bucketEnd, 4)) [$($buckets[$i])] `t|$bar`n"
    }
    
    # Calcular percentis adicionais
    $p10Index = [Math]::Floor($sortedTimes.Count * 0.10)
    $p25Index = [Math]::Floor($sortedTimes.Count * 0.25)
    $p50Index = [Math]::Floor($sortedTimes.Count * 0.50)
    $p75Index = [Math]::Floor($sortedTimes.Count * 0.75)
    $p90Index = [Math]::Floor($sortedTimes.Count * 0.90)
    
    $p10 = if ($p10Index -lt $sortedTimes.Count) { $sortedTimes[$p10Index] / 1000 } else { 0 }  # convertendo para segundos
    $p25 = if ($p25Index -lt $sortedTimes.Count) { $sortedTimes[$p25Index] / 1000 } else { 0 }
    $p50 = if ($p50Index -lt $sortedTimes.Count) { $sortedTimes[$p50Index] / 1000 } else { 0 }
    $p75 = if ($p75Index -lt $sortedTimes.Count) { $sortedTimes[$p75Index] / 1000 } else { 0 }
    $p90 = if ($p90Index -lt $sortedTimes.Count) { $sortedTimes[$p90Index] / 1000 } else { 0 }
    $p95 = $testResult.P95Latency / 1000  # já calculado anteriormente
    $p99 = $testResult.P99Latency / 1000
    
    # Formatar a distribuição de latência
    $latencyDistributionStr = "Latency distribution:`n"
    $latencyDistributionStr += "  10% in $([Math]::Round($p10, 4)) secs`n"
    $latencyDistributionStr += "  25% in $([Math]::Round($p25, 4)) secs`n"
    $latencyDistributionStr += "  50% in $([Math]::Round($p50, 4)) secs`n"
    $latencyDistributionStr += "  75% in $([Math]::Round($p75, 4)) secs`n"
    $latencyDistributionStr += "  90% in $([Math]::Round($p90, 4)) secs`n"
    $latencyDistributionStr += "  95% in $([Math]::Round($p95, 4)) secs`n"
    $latencyDistributionStr += "  99% in $([Math]::Round($p99, 4)) secs`n"
    
    # Detalhes da requisição
    $detailsStr = "Details (average, fastest, slowest):`n"
    $detailsStr += "  Total:        $([Math]::Round($testResult.Duration, 4)) secs`n"
    $detailsStr += "  Slowest:      $([Math]::Round($maxTime / 1000, 4)) secs`n"
    $detailsStr += "  Fastest:      $([Math]::Round($minTime / 1000, 4)) secs`n"
    $detailsStr += "  Average:      $([Math]::Round($testResult.AvgLatency / 1000, 4)) secs`n"
    $detailsStr += "  Requests/sec: $([Math]::Round($testResult.QueriesPerSecond, 4))`n"
    
    # Distribuição de código de status
    $statusDistributionStr = "Status code distribution:`n"
    $statusDistributionStr += "  [200] $($testResult.SuccessCount) responses`n"
    if ($testResult.FailureCount -gt 0) {
        $statusDistributionStr += "  [ERR] $($testResult.FailureCount) responses`n"
    }
    
    # Montar o resultado completo
    $resultStr = @"
Summary:
  Total:        $([Math]::Round($testResult.Duration, 4)) secs
  Slowest:      $([Math]::Round($maxTime / 1000, 4)) secs
  Fastest:      $([Math]::Round($minTime / 1000, 4)) secs
  Average:      $([Math]::Round($testResult.AvgLatency / 1000, 4)) secs
  Requests/sec: $([Math]::Round($testResult.QueriesPerSecond, 4))
  Success rate: $([Math]::Round($testResult.SuccessRate, 2))%
  Total queries: $($testResult.TotalExecuted)

$histogramStr

$latencyDistributionStr

$detailsStr

$statusDistributionStr
"@
} else {
    # Caso não tenha resultados
    $resultStr = @"
Summary:
  Total:        $([Math]::Round($testResult.Duration, 4)) secs
  Requests/sec: $([Math]::Round($testResult.QueriesPerSecond, 4))
  Success rate: $([Math]::Round($testResult.SuccessRate, 2))%
  Total queries: $($testResult.TotalExecuted)
  
No successful responses to calculate latency statistics.
"@
}

# Salvar resultados em arquivo
$resultStr | Out-File -FilePath "$resultsDir/hey-graphql-ingress-result.txt" -Encoding utf8
$resultStr | ForEach-Object { Write-Host $_ }

# Testar o endpoint echo para comparação
Write-Host "==> Executando benchmark para o endpoint GraphQL Echo Ingress..." -ForegroundColor Cyan
$echoUrl = "http://$ingressIP/graphql/echo"
$echoTestResult = Invoke-ConcurrentGraphQLQueries -Url $echoUrl -Query $graphqlQuery -NumQueries $queries -ConcurrentClients $concurrentClients -DurationSec $duration

# Formatar resultado do teste echo
$sortedEchoTimes = $echoTestResult.ResponseTimes | Sort-Object
if ($sortedEchoTimes.Count -gt 0) {
    $minEchoTime = ($sortedEchoTimes | Measure-Object -Minimum).Minimum
    $maxEchoTime = ($sortedEchoTimes | Measure-Object -Maximum).Maximum
    $echoBucketSize = if ($maxEchoTime -gt $minEchoTime) { ($maxEchoTime - $minEchoTime) / $histogramBuckets } else { 1 }
    $echoBuckets = @(0) * $histogramBuckets
    
    foreach ($time in $sortedEchoTimes) {
        $bucketIndex = if ($maxEchoTime -gt $minEchoTime) {
            [Math]::Min([Math]::Floor(($time - $minEchoTime) / $echoBucketSize), $histogramBuckets - 1)
        } else {
            0
        }
        $echoBuckets[$bucketIndex]++
    }
    
    # Encontrar o bucket com mais elementos para normalização
    $maxEchoBucketCount = ($echoBuckets | Measure-Object -Maximum).Maximum
    
    # Criar histograma
    $echoHistogramStr = "Response time histogram (ms):`n"
    for ($i = 0; $i -lt $histogramBuckets; $i++) {
        $bucketStart = ($minEchoTime + ($i * $echoBucketSize)) / 1000
        $bucketEnd = ($minEchoTime + (($i + 1) * $echoBucketSize)) / 1000
        $barLength = if ($maxEchoBucketCount -gt 0) { [Math]::Round(($echoBuckets[$i] / $maxEchoBucketCount) * 40) } else { 0 }
        $bar = if ($barLength -gt 0) { "".PadRight($barLength, "#") } else { "" }
        $echoHistogramStr += "  $([Math]::Round($bucketStart, 4)) - $([Math]::Round($bucketEnd, 4)) [$($echoBuckets[$i])] `t|$bar`n"
    }
    
    # Calcular percentis adicionais
    $echoP10Index = [Math]::Floor($sortedEchoTimes.Count * 0.10)
    $echoP25Index = [Math]::Floor($sortedEchoTimes.Count * 0.25)
    $echoP50Index = [Math]::Floor($sortedEchoTimes.Count * 0.50)
    $echoP75Index = [Math]::Floor($sortedEchoTimes.Count * 0.75)
    $echoP90Index = [Math]::Floor($sortedEchoTimes.Count * 0.90)
    
    $echoP10 = if ($echoP10Index -lt $sortedEchoTimes.Count) { $sortedEchoTimes[$echoP10Index] / 1000 } else { 0 }
    $echoP25 = if ($echoP25Index -lt $sortedEchoTimes.Count) { $sortedEchoTimes[$echoP25Index] / 1000 } else { 0 }
    $echoP50 = if ($echoP50Index -lt $sortedEchoTimes.Count) { $sortedEchoTimes[$echoP50Index] / 1000 } else { 0 }
    $echoP75 = if ($echoP75Index -lt $sortedEchoTimes.Count) { $sortedEchoTimes[$echoP75Index] / 1000 } else { 0 }
    $echoP90 = if ($echoP90Index -lt $sortedEchoTimes.Count) { $sortedEchoTimes[$echoP90Index] / 1000 } else { 0 }
    $echoP95 = $echoTestResult.P95Latency / 1000
    $echoP99 = $echoTestResult.P99Latency / 1000
    
    # Formatar a distribuição de latência
    $echoLatencyDistributionStr = "Latency distribution:`n"
    $echoLatencyDistributionStr += "  10% in $([Math]::Round($echoP10, 4)) secs`n"
    $echoLatencyDistributionStr += "  25% in $([Math]::Round($echoP25, 4)) secs`n"
    $echoLatencyDistributionStr += "  50% in $([Math]::Round($echoP50, 4)) secs`n"
    $echoLatencyDistributionStr += "  75% in $([Math]::Round($echoP75, 4)) secs`n"
    $echoLatencyDistributionStr += "  90% in $([Math]::Round($echoP90, 4)) secs`n"
    $echoLatencyDistributionStr += "  95% in $([Math]::Round($echoP95, 4)) secs`n"
    $echoLatencyDistributionStr += "  99% in $([Math]::Round($echoP99, 4)) secs`n"
    
    # Detalhes da requisição
    $echoDetailsStr = "Details (average, fastest, slowest):`n"
    $echoDetailsStr += "  Total:        $([Math]::Round($echoTestResult.Duration, 4)) secs`n"
    $echoDetailsStr += "  Slowest:      $([Math]::Round($maxEchoTime / 1000, 4)) secs`n"
    $echoDetailsStr += "  Fastest:      $([Math]::Round($minEchoTime / 1000, 4)) secs`n"
    $echoDetailsStr += "  Average:      $([Math]::Round($echoTestResult.AvgLatency / 1000, 4)) secs`n"
    $echoDetailsStr += "  Requests/sec: $([Math]::Round($echoTestResult.QueriesPerSecond, 4))`n"
    
    # Distribuição de código de status
    $echoStatusDistributionStr = "Status code distribution:`n"
    $echoStatusDistributionStr += "  [200] $($echoTestResult.SuccessCount) responses`n"
    if ($echoTestResult.FailureCount -gt 0) {
        $echoStatusDistributionStr += "  [ERR] $($echoTestResult.FailureCount) responses`n"
    }
    
    # Montar o resultado completo
    $echoResultStr = @"
Summary:
  Total:        $([Math]::Round($echoTestResult.Duration, 4)) secs
  Slowest:      $([Math]::Round($maxEchoTime / 1000, 4)) secs
  Fastest:      $([Math]::Round($minEchoTime / 1000, 4)) secs
  Average:      $([Math]::Round($echoTestResult.AvgLatency / 1000, 4)) secs
  Requests/sec: $([Math]::Round($echoTestResult.QueriesPerSecond, 4))
  Success rate: $([Math]::Round($echoTestResult.SuccessRate, 2))%
  Total queries: $($echoTestResult.TotalExecuted)

$echoHistogramStr

$echoLatencyDistributionStr

$echoDetailsStr

$echoStatusDistributionStr
"@
} else {
    # Caso não tenha resultados
    $echoResultStr = @"
Summary:
  Total:        $([Math]::Round($echoTestResult.Duration, 4)) secs
  Requests/sec: $([Math]::Round($echoTestResult.QueriesPerSecond, 4))
  Success rate: $([Math]::Round($echoTestResult.SuccessRate, 2))%
  Total queries: $($echoTestResult.TotalExecuted)
  
No successful responses to calculate latency statistics.
"@
}

# Salvar resultados do teste echo em arquivo
$echoResultStr | Out-File -FilePath "$resultsDir/hey-graphql-echo-ingress-result.txt" -Encoding utf8

# Aguardar finalização da coleta de métricas do Docker
Write-Host "Aguardando conclusão da coleta de métricas Docker..." -ForegroundColor Gray
$collectDockerMetricsJob | Wait-Job | Receive-Job
$collectDockerMetricsJob | Remove-Job

Write-Host "==> Benchmark GraphQL Ingress concluído!" -ForegroundColor Green
Write-Host "Resultados salvos em $resultsDir" 