# Verifica se o Docker está instalado
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[ERRO] Docker não está instalado. Instale o Docker Desktop antes de continuar." -ForegroundColor Red
    exit 1
}

# Verifica se o Docker está rodando
# Usando $LASTEXITCODE para maior compatibilidade

docker info | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRO] Docker não está rodando. Inicie o Docker Desktop antes de continuar." -ForegroundColor Red
    exit 1
}

# Verifica se o KIND está instalado
if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
    Write-Host "[ERRO] KIND não está instalado. Instale o KIND antes de continuar." -ForegroundColor Red
    exit 1
}

# Verifica se o kubectl está instalado
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "[ERRO] kubectl não está instalado. Instale o kubectl antes de continuar." -ForegroundColor Red
    exit 1
}

# Remove o cluster se já existir
$clusterName = "comparativo-ingress-apigw"
$existingClusters = kind get clusters
if ($existingClusters -contains $clusterName) {
    Write-Host "[INFO] Cluster '$clusterName' já existe. Removendo antes de criar novamente..." -ForegroundColor Yellow
    kind delete cluster --name $clusterName
}

Write-Host "==> Criando o cluster KIND..." -ForegroundColor Cyan
kind create cluster --name $clusterName --config kind/kind-config.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRO] Falha ao criar o cluster KIND." -ForegroundColor Red
    exit 1
}

Write-Host "==> Aguardando node ficar Ready..." -ForegroundColor Cyan
$nodeReady = $false
for ($i=0; $i -lt 30; $i++) {
    $status = kubectl get nodes --no-headers | Select-String " Ready "
    if ($status) {
        $nodeReady = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $nodeReady) {
    Write-Host "[ERRO] Node não ficou Ready após 60 segundos." -ForegroundColor Red
    exit 1
}

Write-Host "==> Cluster criado e node pronto!" -ForegroundColor Green
kubectl get nodes 