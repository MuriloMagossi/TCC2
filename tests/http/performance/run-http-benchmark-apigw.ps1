# tests/http/performance/run-http-benchmark-apigw.ps1

# Baixa o hey.exe automaticamente se não existir
if (-not (Test-Path "./hey.exe")) {
    Write-Host "==> Baixando hey.exe..." -ForegroundColor Cyan
    $heyUrl = "https://hey-release.s3.us-east-2.amazonaws.com/hey_windows_amd64"
    try {
        Invoke-WebRequest -Uri $heyUrl -OutFile "hey.exe"
    } catch {
        Write-Host "[ERRO] Falha ao baixar hey.exe: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    if (-not (Test-Path "./hey.exe") -or (Get-Item "./hey.exe").Length -lt 10000) {
        Write-Host "[ERRO] hey.exe não foi baixado corretamente. Baixe manualmente do site oficial e coloque na pasta do script." -ForegroundColor Red
        exit 1
    }
    Write-Host "==> hey.exe baixado com sucesso." -ForegroundColor Green
}

# Parâmetros do teste
$targetUrl = "http://localhost:30082/"
$conns = 100
$requests = 1000
$duration = 30 # segundos

# Caminho do hey (ajuste se necessário)
$heyPath = "hey.exe"

# Diretório e arquivo para salvar métricas do Docker
$resultsDir = "tests/http/performance/results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}
$dockerStatsFile = "$resultsDir/docker-stats-http-apigw.csv"
$dockerStatsHeader = "Name,CPU %,Mem Usage / Limit,Net I/O,Block I/O"
Set-Content -Path $dockerStatsFile -Value $dockerStatsHeader

Write-Host "==> Iniciando benchmark HTTP (API Gateway) com hey em background..." -ForegroundColor Cyan
$heyProcess = Start-Process -FilePath "./hey.exe" -ArgumentList "-c $conns -n $requests -z ${duration}s $targetUrl" -NoNewWindow -PassThru -RedirectStandardOutput "$resultsDir/hey-http-apigw-result.txt"

Write-Host "==> Coletando métricas do Docker enquanto o benchmark roda..." -ForegroundColor Cyan
while (-not $heyProcess.HasExited) {
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" | Add-Content -Path $dockerStatsFile
    Start-Sleep -Seconds 1
}

Write-Host "==> Coleta de métricas e benchmark finalizados." -ForegroundColor Green
Write-Host "Resultados salvos em $resultsDir" 