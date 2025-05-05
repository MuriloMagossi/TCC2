# tests/http/performance/run-http-benchmark-ingress.ps1

# IMPORTANTE: Antes de executar este script, certifique-se de ter um port-forward configurado:
# kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80 --address 0.0.0.0
# (Execute em uma janela separada do PowerShell)

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

# Verificar se o serviço Ingress Controller está exposto como NodePort
Write-Host "==> Verificando NodePort do Ingress Controller..." -ForegroundColor Cyan
try {
    $nodePort = kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath="{.spec.ports[?(@.port==80)].nodePort}"
    if (-not $nodePort) {
        throw "Não foi possível obter a porta do NodePort para o Ingress Controller"
    }
    Write-Host "==> Ingress Controller está exposto na porta $nodePort (NodePort)" -ForegroundColor Green
} catch {
    Write-Host "[ERRO] $($_.Exception.Message)" -ForegroundColor Red
    # Valor observado nos comandos anteriores
    Write-Host "==> Usando porta padrão 31150..." -ForegroundColor Yellow
    $nodePort = 31150
}

# Parâmetros do teste
$targetUrl = "http://localhost:$nodePort/"
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
$dockerStatsFile = "$resultsDir/docker-stats-http-ingress.csv"
$dockerStatsHeader = "Name,CPU %,Mem Usage / Limit,Net I/O,Block I/O"
Set-Content -Path $dockerStatsFile -Value $dockerStatsHeader

# Testar conectividade antes de iniciar o benchmark
Write-Host "==> Testando conectividade com o Ingress Controller..." -ForegroundColor Cyan
try {
    $testResponse = Invoke-WebRequest -Uri $targetUrl -Headers @{"Host" = "http.localtest.me"} -UseBasicParsing -TimeoutSec 5
    Write-Host "==> Conectividade OK (Status: $($testResponse.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "[ERRO] Falha ao conectar com o Ingress Controller: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "==> Continuando mesmo assim..." -ForegroundColor Yellow
}

Write-Host "==> Iniciando benchmark HTTP (Ingress) com hey em background..." -ForegroundColor Cyan

# Criar um arquivo CMD temporário com o comando completo
$tempCmdFile = [System.IO.Path]::GetTempFileName() + ".cmd"
$heyCmd = "$heyPath -c $conns -n $requests -z ${duration}s -H ""Host: http.localtest.me"" $targetUrl > ""$resultsDir/hey-http-ingress-result.txt"""
Set-Content -Path $tempCmdFile -Value $heyCmd

# Executar o arquivo CMD
$heyProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $tempCmdFile -NoNewWindow -PassThru

Write-Host "==> Coletando metricas do Docker enquanto o benchmark roda..." -ForegroundColor Cyan
while (-not $heyProcess.HasExited) {
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" | Add-Content -Path $dockerStatsFile
    Start-Sleep -Seconds 1
}

# Remover o arquivo temporário
Remove-Item -Path $tempCmdFile -Force -ErrorAction SilentlyContinue

Write-Host "==> Coleta de metricas e benchmark finalizados." -ForegroundColor Green
Write-Host "Resultados salvos em $resultsDir" 