# tests/tcp/performance/run-tcp-benchmark-apigw.ps1

# Detectar NodePort do API Gateway TCP
$apigwPort = kubectl get svc nginx-apigw-tcp -n tcp -o jsonpath="{.spec.ports[0].nodePort}"

# Parâmetros do teste
$conns = 20
$requests = 40
$duration = 30 # segundos
$resultsDir = "tests/tcp/performance/results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}
$dockerStatsFile = "$resultsDir/docker-stats-tcp-apigw.csv"
$dockerStatsHeader = "Name,CPU %,Mem Usage / Limit,Net I/O,Block I/O"
Set-Content -Path $dockerStatsFile -Value $dockerStatsHeader
$tcpResultFile = "$resultsDir/tcp-apigw-result.txt"

Write-Host "==> Iniciando benchmark TCP (API Gateway) com $conns conexões em paralelo..." -ForegroundColor Cyan
$jobs = @()
$requestsPerConn = [math]::Ceiling($requests / $conns)
$startTime = Get-Date
for ($i = 0; $i -lt $conns; $i++) {
    $jobs += Start-Job -ScriptBlock {
        param($hostname, $port, $reqs)
        function Invoke-TcpRequest {
            param(
                [string]$hostname,
                [int]$port,
                [int]$requests
            )
            $success = 0
            $fail = 0
            $latencies = @()
            try {
                $client = New-Object System.Net.Sockets.TcpClient($hostname, $port)
                $stream = $client.GetStream()
                $writer = New-Object System.IO.StreamWriter($stream)
                $reader = New-Object System.IO.StreamReader($stream)
                for ($i = 0; $i -lt $requests; $i++) {
                    $msg = "bench-tcp-apigw-$i"
                    try {
                        $start = [datetime]::Now
                        $writer.WriteLine($msg)
                        $writer.Flush()
                        $null = $reader.ReadLine() # Ignora resposta
                        $end = [datetime]::Now
                        $latencies += ($end - $start).TotalMilliseconds
                        $success++
                    } catch {
                        $fail++
                    }
                }
                $writer.Close()
                $reader.Close()
                $client.Close()
            } catch {
                $fail += $requests
            }
            return @{success=$success;fail=$fail;latencies=$latencies}
        }
        Invoke-TcpRequest -hostname $hostname -port $port -requests $reqs
    } -ArgumentList @("localhost", $apigwPort, $requestsPerConn)
}

Write-Host "==> Coletando métricas do Docker enquanto o benchmark roda..." -ForegroundColor Cyan
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
while ($jobs | Where-Object { $_.State -eq 'Running' } -and $stopWatch.Elapsed.TotalSeconds -lt $duration) {
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" | Add-Content -Path $dockerStatsFile
    Start-Sleep -Seconds 1
}
$stopWatch.Stop()

# Aguarda todos os jobs terminarem
timeout 5 $jobs | Wait-Job | Out-Null
$endTime = Get-Date
$elapsed = $endTime - $startTime

# Coleta resultados dos jobs
$results = $jobs | ForEach-Object { Receive-Job -Job $_ }
$jobs | Remove-Job | Out-Null

$totalSuccess = ($results | ForEach-Object { $_.success }) -as [int[]] | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$totalFail = ($results | ForEach-Object { $_.fail }) -as [int[]] | Measure-Object -Sum | Select-Object -ExpandProperty Sum

# Coleta e calcula latências
$allLatencies = @()
$results | ForEach-Object { $allLatencies += $_.latencies }
$latencyCount = $allLatencies.Count
$latencyAvg = if ($latencyCount -gt 0) { [math]::Round(($allLatencies | Measure-Object -Average).Average, 2) } else { 0 }
$latencyMin = if ($latencyCount -gt 0) { [math]::Round(($allLatencies | Measure-Object -Minimum).Minimum, 2) } else { 0 }
$latencyMax = if ($latencyCount -gt 0) { [math]::Round(($allLatencies | Measure-Object -Maximum).Maximum, 2) } else { 0 }

# Throughput (mensagens/s)
$throughput = if ($elapsed.TotalSeconds -gt 0) { [math]::Round($totalSuccess / $elapsed.TotalSeconds, 2) } else { 0 }

Write-Host "==> Coleta de métricas e benchmark finalizados." -ForegroundColor Green
Write-Host "Tempo total: $($elapsed.TotalSeconds) segundos"
Write-Host "Latência média: $latencyAvg ms | min: $latencyMin ms | max: $latencyMax ms"
Write-Host "Throughput: $throughput msgs/s"
Write-Host "Resultados salvos em $resultsDir"

# Salva resumo detalhado
Add-Content -Path $tcpResultFile -Value "Benchmark TCP API Gateway"
Add-Content -Path $tcpResultFile -Value "Conexões paralelas: $conns"
Add-Content -Path $tcpResultFile -Value "Requisições totais: $requests"
Add-Content -Path $tcpResultFile -Value "Tempo total (s): $($elapsed.TotalSeconds)"
Add-Content -Path $tcpResultFile -Value "Sucessos: $totalSuccess"
Add-Content -Path $tcpResultFile -Value "Falhas: $totalFail"
Add-Content -Path $tcpResultFile -Value "Latência média (ms): $latencyAvg"
Add-Content -Path $tcpResultFile -Value "Latência min (ms): $latencyMin"
Add-Content -Path $tcpResultFile -Value "Latência max (ms): $latencyMax"
Add-Content -Path $tcpResultFile -Value "Throughput (msgs/s): $throughput"
Add-Content -Path $tcpResultFile -Value "Resultados detalhados por conexão:"
$results | ForEach-Object { Add-Content -Path $tcpResultFile -Value ("Sucessos: " + $_.success + ", Falhas: " + $_.fail) } 