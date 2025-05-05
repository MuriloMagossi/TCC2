# Script para carregar apenas o Ingress Controller
Write-Host "Carregando o Ingress Controller..."

# Verificar se o cluster existe
$clusterExists = kind get clusters | Select-String "tcc3"
if (-not $clusterExists) {
    Write-Host "Cluster tcc3 não encontrado. Por favor, execute setup-environments.ps1 primeiro."
    exit 1
}

# Definir o caminho correto para o arquivo
$projectRoot = Split-Path -Parent $PSScriptRoot
$ingressYamlPath = Join-Path $projectRoot "manifests\api-gateway\ingress-nginx.yaml"

# Verificar se o arquivo existe
if (-not (Test-Path $ingressYamlPath)) {
    Write-Host "Arquivo $ingressYamlPath não encontrado!"
    exit 1
}

# Remover o Ingress Controller existente
Write-Host "Removendo o Ingress Controller existente..."
kubectl delete -f $ingressYamlPath --ignore-not-found=true

# Aguardar a remoção completa
Write-Host "Aguardando a remoção completa..."
Start-Sleep -Seconds 5

# Aplicar o novo Ingress Controller
Write-Host "Aplicando o novo Ingress Controller..."
kubectl apply -f $ingressYamlPath

# Aguardar o Ingress Controller estar pronto
Write-Host "Aguardando o Ingress Controller estar pronto..."
$maxAttempts = 6
$attempt = 0
$ingressReady = $false

while (-not $ingressReady -and $attempt -lt $maxAttempts) {
    $attempt++
    Write-Host "Tentativa $attempt de $maxAttempts..."
    
    # Verificar status do pod
    $podStatus = kubectl get pods -n ingress-nginx -l app=ingress-nginx -o jsonpath='{.items[0].status.phase}'
    Write-Host "Status do pod: $podStatus"
    
    if ($podStatus -eq "Running") {
        $containerReady = kubectl get pods -n ingress-nginx -l app=ingress-nginx -o jsonpath='{.items[0].status.containerStatuses[0].ready}'
        Write-Host "Container pronto: $containerReady"
        
        if ($containerReady -eq "true") {
            $ingressReady = $true
            Write-Host "Ingress Controller está pronto!"
        } else {
            # Mostrar logs do pod para debug
            Write-Host "Logs do pod:"
            kubectl logs -n ingress-nginx -l app=ingress-nginx
            Write-Host "Container ainda não está pronto, aguardando..."
            Start-Sleep -Seconds 10
        }
    } else {
        # Mostrar descrição do pod para debug
        Write-Host "Descrição do pod:"
        kubectl describe pod -n ingress-nginx -l app=ingress-nginx
        Write-Host "Pod ainda não está rodando, aguardando..."
        Start-Sleep -Seconds 10
    }
}

if (-not $ingressReady) {
    Write-Host "Timeout aguardando o Ingress Controller estar pronto"
    Write-Host "Último status do pod:"
    kubectl get pods -n ingress-nginx -l app=ingress-nginx -o wide
    Write-Host "Últimos logs do pod:"
    kubectl logs -n ingress-nginx -l app=ingress-nginx
    exit 1
}

Write-Host "Ingress Controller carregado com sucesso!" 