# tests/https/performance/run-https-benchmark-ingress.ps1

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
$targetUrl = "https://localhost:8443/"
$conns = 100
$requests = 1000
$duration = 30 # segundos

# Diretório e arquivo para salvar métricas do Docker
$resultsDir = "tests/https/performance/results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}
$dockerStatsFile = "$resultsDir/docker-stats-https-ingress.csv"
$dockerStatsHeader = "Name,CPU %,Mem Usage / Limit,Net I/O,Block I/O"
Set-Content -Path $dockerStatsFile -Value $dockerStatsHeader

# Inicia o port-forward do ingress-nginx-controller para a porta 8443
Write-Host "==> Iniciando port-forward do ingress-nginx-controller para localhost:8443..." -ForegroundColor Cyan
$portForward = Start-Process -FilePath "kubectl" -ArgumentList @("port-forward", "-n", "ingress-nginx", "svc/ingress-nginx-controller", "8443:443") -NoNewWindow -PassThru
Start-Sleep -Seconds 3 # Aguarda o port-forward iniciar

Write-Host "==> Iniciando benchmark HTTPS (Ingress) com hey em background..." -ForegroundColor Cyan
$heyProcess = Start-Process -FilePath "./hey.exe" -ArgumentList "-c $conns -n $requests -z ${duration}s -host https.localtest.me $targetUrl" -NoNewWindow -PassThru -RedirectStandardOutput "$resultsDir/hey-https-ingress-result.txt"

Write-Host "==> Coletando métricas do Docker enquanto o benchmark roda..." -ForegroundColor Cyan
while (-not $heyProcess.HasExited) {
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" | Add-Content -Path $dockerStatsFile
    Start-Sleep -Seconds 1
}

# Finaliza o port-forward
Write-Host "==> Finalizando port-forward..." -ForegroundColor Cyan
Stop-Process -Id $portForward.Id -Force

Write-Host "==> Coleta de métricas e benchmark finalizados." -ForegroundColor Green
Write-Host "Resultados salvos em $resultsDir" 