# tests/grpc/performance/run-grpc-benchmark-ingress.ps1

# =========================
# 1. Instalação do ghz
# =========================
if (-not (Test-Path "./ghz.exe")) {
    Write-Host "==> Instalando ghz via Go..." -ForegroundColor Cyan
    if (-not (Get-Command "go" -ErrorAction SilentlyContinue)) {
        Write-Host "[ERRO] Go não está instalado. Por favor instale o Go antes de continuar." -ForegroundColor Red
        exit 1
    }
    try {
        $env:GO111MODULE = "on"
        go install github.com/bojand/ghz/cmd/ghz@latest
        $goPath = if ($env:GOPATH) { $env:GOPATH } else { Join-Path $env:USERPROFILE "go" }
        Copy-Item "$goPath\bin\ghz.exe" -Destination "."
        if (-not (Test-Path "./ghz.exe")) {
            throw "Falha ao copiar ghz.exe do GOPATH"
        }
    } catch {
        Write-Host "[ERRO] Falha ao instalar ghz via Go: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    Write-Host "==> ghz instalado com sucesso via Go." -ForegroundColor Green
}

# =========================
# 2. Readiness do pod grpc-echo
# =========================
Write-Host "==> Aguardando pod grpc-echo ficar pronto..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod -l app=grpc-echo -n grpc --timeout=60s

# =========================
# 3. Parâmetros do benchmark
# =========================
$target = "localhost:30900"
$method = "grpcbin.GRPCBin/Empty"
$conns = 100
$requests = 1000
$duration = 30 # segundos

# =========================
# 4. Diretório e arquivo para métricas
# =========================
$resultsDir = "tests/grpc/performance/results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}
$dockerStatsFile = "$resultsDir/docker-stats-grpc-ingress.csv"
$dockerStatsHeader = "Name,CPU %,Mem Usage / Limit,Net I/O,Block I/O"
Set-Content -Path $dockerStatsFile -Value $dockerStatsHeader

# =========================
# 5. Executa o benchmark
# =========================
Write-Host "==> Iniciando benchmark gRPC (Ingress Controller) com ghz..." -ForegroundColor Cyan
Write-Host "==> Conectando em $target" -ForegroundColor Cyan
$ghzProcess = Start-Process -FilePath "./ghz.exe" -ArgumentList "--insecure --concurrency $conns --total $requests --duration ${duration}s --call $method $target" -NoNewWindow -PassThru -RedirectStandardOutput "$resultsDir/ghz-grpc-ingress-result.txt"

# =========================
# 6. Coleta métricas do Docker enquanto o benchmark roda
# =========================
Write-Host "==> Coletando métricas do Docker enquanto o benchmark roda..." -ForegroundColor Cyan
while (-not $ghzProcess.HasExited) {
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" | Add-Content -Path $dockerStatsFile
    Start-Sleep -Seconds 1
}

Write-Host "==> Coleta de métricas e benchmark finalizados." -ForegroundColor Green
Write-Host "Resultados salvos em $resultsDir" 