# Define protocols array at the beginning
$protocols = @("http", "https", "websocket", "graphql", "tcp")

# Função para verificar e instalar dependências
function Test-Dependencies {
    Write-Host "Checking and installing dependencies..."
    
    # Verificar se kubectl está instalado
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Host "kubectl not found. Please install kubectl first."
        exit 1
    }

    # Verificar se kind está instalado
    if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
        Write-Host "kind not found. Please install kind first."
        exit 1
    }

    # Verificar se Docker está instalado e rodando
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Docker not found. Please install Docker first."
        exit 1
    }

    # Verificar se Python está instalado
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "Python not found. Please install Python first."
        exit 1
    }

    # Verificar e instalar dependências Python
    if (Test-Path "../requirements.txt") {
        Write-Host "Installing Python dependencies..."
        python -m pip install -r ../requirements.txt
    } else {
        Write-Host "requirements.txt not found. Skipping Python dependencies."
    }

    # Verificar ferramentas de teste (apenas aviso, não bloqueia a execução)
    Write-Host "Checking test tools..."
    
    if (-not (Test-Path "hey.exe")) {
        Write-Host "Warning: hey not found. Tests will not be available."
    }

    if (-not (Test-Path "websocat.exe")) {
        Write-Host "Warning: websocat not found. Tests will not be available."
    }

    if (-not (Test-Path "ghz.exe")) {
        Write-Host "Warning: ghz not found. Tests will not be available."
    }

    if (-not (Test-Path "bombardier.exe")) {
        Write-Host "Warning: bombardier not found. Tests will not be available."
    }

    Write-Host "All dependencies checked successfully!"
}

# Função para gerar certificado auto-assinado usando PowerShell
function New-SelfSignedCertificate {
    param (
        [string]$OutputPath
    )

    Write-Host "Gerando certificado auto-assinado..."
    
    # Criar certificado auto-assinado
    $cert = New-SelfSignedCertificate -Subject "CN=localhost" -NotAfter (Get-Date).AddYears(1) -CertStoreLocation "Cert:\CurrentUser\My" -KeyAlgorithm RSA -KeyLength 2048
    
    # Exportar certificado e chave privada
    $password = ConvertTo-SecureString -String "password" -Force -AsPlainText
    
    # Exportar certificado
    Export-PfxCertificate -Cert $cert -FilePath "$OutputPath\tls.pfx" -Password $password
    
    # Exportar certificado público
    Export-Certificate -Cert $cert -FilePath "$OutputPath\tls.crt" -Type CERT
    
    # Exportar chave privada
    $certPath = "Cert:\CurrentUser\My\$($cert.Thumbprint)"
    $keyPath = "$OutputPath\tls.key"
    $keyContent = [System.Convert]::ToBase64String($cert.PrivateKey.Key)
    Set-Content -Path $keyPath -Value $keyContent
    
    # Copiar certificado como CA
    Copy-Item "$OutputPath\tls.crt" "$OutputPath\ca.crt"
    
    # Remover certificado do store
    Remove-Item $certPath -Force
    
    Write-Host "Certificados gerados com sucesso!"
}

# Função para criar namespace e aplicar manifestos
function Initialize-Environment {
    param (
        [string]$namespace,
        [string]$protocol,
        [string]$gateway_type
    )

    Write-Host "Setting up $gateway_type environment for $protocol in namespace $namespace"
    
    # Obter o caminho base do projeto
    $projectRoot = Split-Path -Parent $PSScriptRoot
    
    # Criar namespace
    kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
    
    # Se for HTTPS, criar o secret com os certificados SSL
    if ($protocol -eq "https") {
        Write-Host "Criando secret com certificados SSL para HTTPS..."
        $certsPath = Join-Path $projectRoot "certs"
        
        # Se o diretório de certificados não existir, criar e gerar certificados
        if (-not (Test-Path $certsPath)) {
            Write-Host "Diretório de certificados não encontrado. Criando e gerando certificados SSL..."
            New-Item -ItemType Directory -Path $certsPath -Force | Out-Null
            
            # Gerar certificados usando PowerShell
            New-SelfSignedCertificate -OutputPath $certsPath
        }
        
        # Criar o secret com os certificados
        kubectl create secret generic ssl-certs -n $namespace `
            --from-file=tls.crt="$certsPath/tls.crt" `
            --from-file=tls.key="$certsPath/tls.key" `
            --from-file=ca.crt="$certsPath/ca.crt" `
            --dry-run=client -o yaml | kubectl apply -f -
    }
    
    # Aplicar manifestos do serviço
    if ($gateway_type -eq "ingress") {
        $deploymentPath = Join-Path $projectRoot "manifests\ingress-controller\$protocol\deployment.yaml"
        $ingressPath = Join-Path $projectRoot "manifests\ingress-controller\$protocol\ingress.yaml"
        
        if (-not (Test-Path $deploymentPath)) {
            Write-Host "Arquivo não encontrado: $deploymentPath"
            exit 1
        }
        if (-not (Test-Path $ingressPath)) {
            Write-Host "Arquivo não encontrado: $ingressPath"
            exit 1
        }
        
        kubectl apply -f $deploymentPath -n $namespace
        kubectl apply -f $ingressPath -n $namespace
    } elseif ($gateway_type -eq "api-gateway") {
        $namespacePath = Join-Path $projectRoot "manifests\api-gateway\$protocol\namespace.yaml"
        $deploymentPath = Join-Path $projectRoot "manifests\api-gateway\$protocol\deployment.yaml"
        
        if (-not (Test-Path $namespacePath)) {
            Write-Host "Arquivo não encontrado: $namespacePath"
            exit 1
        }
        if (-not (Test-Path $deploymentPath)) {
            Write-Host "Arquivo não encontrado: $deploymentPath"
            exit 1
        }
        
        kubectl apply -f $namespacePath
        kubectl apply -f $deploymentPath -n $namespace
    }
    
    # Aguardar os pods estarem prontos com timeout reduzido
    Write-Host "Aguardando pod do serviço $protocol estar pronto..."
    $maxAttempts = 3
    $attempt = 0
    $podReady = $false

    while (-not $podReady -and $attempt -lt $maxAttempts) {
        $attempt++
        Write-Host "Tentativa $attempt de $maxAttempts para o serviço $protocol..."
        
        $podStatus = kubectl get pods -n $namespace -l app=${protocol}-service -o jsonpath='{.items[0].status.phase}'
        Write-Host "Status do pod: $podStatus"
        
        if ($podStatus -eq "Running") {
            $containerReady = kubectl get pods -n $namespace -l app=${protocol}-service -o jsonpath='{.items[0].status.containerStatuses[0].ready}'
            Write-Host "Container pronto: $containerReady"
            
            if ($containerReady -eq "true") {
                $podReady = $true
                Write-Host "Pod do serviço $protocol está pronto!"
            } else {
                Write-Host "Container ainda não está pronto, aguardando..."
                Start-Sleep -Seconds 5
            }
        } else {
            if ($podStatus -eq "Pending") {
                $podName = kubectl get pods -n $namespace -l app=${protocol}-service -o jsonpath='{.items[0].metadata.name}'
                Write-Host "Pod $podName está em estado Pending. Verificando eventos..."
                kubectl describe pod $podName -n $namespace
                Write-Host "Verificando se a imagem existe localmente..."
                $imageName = kubectl get pod $podName -n $namespace -o jsonpath='{.spec.containers[0].image}'
                Write-Host "Imagem do pod: $imageName"
                docker images | Select-String $imageName.Split(':')[0]
            }
            Write-Host "Pod ainda não está rodando, aguardando..."
            Start-Sleep -Seconds 5
        }
    }

    if (-not $podReady) {
        Write-Host "Timeout aguardando o pod do serviço $protocol estar pronto"
        Write-Host "Último status do pod:"
        kubectl get pods -n $namespace -l app=${protocol}-service -o wide
        Write-Host "Descrição detalhada do pod:"
        kubectl describe pod -n $namespace -l app=${protocol}-service
        Write-Host "Logs do pod:"
        kubectl logs -n $namespace -l app=${protocol}-service
        exit 1
    }

    if ($gateway_type -eq "api-gateway") {
        Write-Host "Aguardando pod do API Gateway $protocol estar pronto..."
        $maxAttempts = 3
        $attempt = 0
        $gatewayReady = $false

        while (-not $gatewayReady -and $attempt -lt $maxAttempts) {
            $attempt++
            Write-Host "Tentativa $attempt de $maxAttempts para o API Gateway $protocol..."
            
            $podStatus = kubectl get pods -n $namespace -l app=${protocol}-api-gateway -o jsonpath='{.items[0].status.phase}'
            Write-Host "Status do pod: $podStatus"
            
            if ($podStatus -eq "Running") {
                $containerReady = kubectl get pods -n $namespace -l app=${protocol}-api-gateway -o jsonpath='{.items[0].status.containerStatuses[0].ready}'
                Write-Host "Container pronto: $containerReady"
                
                if ($containerReady -eq "true") {
                    $gatewayReady = $true
                    Write-Host "Pod do API Gateway $protocol está pronto!"
                } else {
                    Write-Host "Container ainda não está pronto, aguardando..."
                    Start-Sleep -Seconds 5
                }
            } else {
                if ($podStatus -eq "Pending") {
                    $podName = kubectl get pods -n $namespace -l app=${protocol}-api-gateway -o jsonpath='{.items[0].metadata.name}'
                    Write-Host "Pod $podName está em estado Pending. Verificando eventos..."
                    kubectl describe pod $podName -n $namespace
                    Write-Host "Verificando se a imagem existe localmente..."
                    $imageName = kubectl get pod $podName -n $namespace -o jsonpath='{.spec.containers[0].image}'
                    Write-Host "Imagem do pod: $imageName"
                    docker images | Select-String $imageName.Split(':')[0]
                }
                Write-Host "Pod ainda não está rodando, aguardando..."
                Start-Sleep -Seconds 5
            }
        }

        if (-not $gatewayReady) {
            Write-Host "Timeout aguardando o pod do API Gateway $protocol estar pronto"
            Write-Host "Último status do pod:"
            kubectl get pods -n $namespace -l app=${protocol}-api-gateway -o wide
            Write-Host "Descrição detalhada do pod:"
            kubectl describe pod -n $namespace -l app=${protocol}-api-gateway
            Write-Host "Logs do pod:"
            kubectl logs -n $namespace -l app=${protocol}-api-gateway
            exit 1
        }
    }
}

# Verificar e instalar dependências antes de prosseguir
Test-Dependencies

# Excluir o cluster antigo
Write-Host "Excluindo o cluster antigo..."
kind delete cluster --name tcc3

# Excluir as imagens antigas
Write-Host "Excluindo as imagens antigas..."
$images = @("tcc3-base:latest")
$images += $protocols | ForEach-Object { "tcc3-${_}:latest" }

foreach ($image in $images) {
    Write-Host "Removendo imagem $image (se existir)..."
    docker rmi $image -f 2>$null
}

# Criar um novo cluster
Write-Host "Criando um novo cluster..."
kind create cluster --name tcc3

# Adicionar label ao node
Write-Host "Adicionando label ao node..."
kubectl label node tcc3-control-plane ingress-ready=true

# Construir e carregar as imagens
Write-Host "Construindo e carregando as imagens..."

# Construir imagem base primeiro
Write-Host "Construindo imagem base..."
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -Path $projectRoot  # Move to project root
docker build -t tcc3-base:latest -f docker/Dockerfile.base docker
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao construir imagem base"
    exit 1
}
Set-Location -Path "scripts"  # Return to scripts directory

# Construir e carregar imagens dos protocolos
foreach ($protocol in $protocols) {
    Write-Host "Construindo imagem para $protocol..."
    Set-Location -Path $projectRoot  # Move to project root
    docker build -t tcc3-${protocol}:latest -f docker/${protocol}/Dockerfile docker/${protocol}
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro ao construir imagem para $protocol"
        exit 1
    }
    Write-Host "Carregando imagem para $protocol..."
    kind load docker-image tcc3-${protocol}:latest --name tcc3
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro ao carregar imagem para $protocol"
        exit 1
    }
    Set-Location -Path "scripts"  # Return to scripts directory
}

# Instalar o Ingress Controller
Write-Host "Instalando o Ingress Controller..."
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -Path $projectRoot  # Move to project root
kubectl apply -f manifests/api-gateway/ingress-nginx.yaml
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao instalar o Ingress Controller. Verifique se o arquivo ingress-nginx.yaml existe e está correto."
    exit 1
}
Set-Location -Path "scripts"  # Return to scripts directory

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
    
    if ($podStatus -eq "Running") {
        $containerReady = kubectl get pods -n ingress-nginx -l app=ingress-nginx -o jsonpath='{.items[0].status.containerStatuses[0].ready}'
        
        if ($containerReady -eq "true") {
            $ingressReady = $true
            Write-Host "Ingress Controller está pronto!"
        } else {
            Write-Host "Container ainda não está pronto, aguardando..."
            Start-Sleep -Seconds 10
        }
    } else {
        Write-Host "Pod ainda não está rodando, aguardando..."
        Start-Sleep -Seconds 10
    }
}

if (-not $ingressReady) {
    Write-Host "Timeout aguardando o Ingress Controller estar pronto"
    Write-Host "Último status do pod:"
    kubectl get pods -n ingress-nginx -l app=ingress-nginx -o wide
    exit 1
}

# Criar ambientes para cada protocolo
foreach ($protocol in $protocols) {
    Initialize-Environment "${protocol}-ingress" $protocol "ingress"
}

# Criar ambientes com API Gateway
foreach ($protocol in $protocols) {
    Initialize-Environment "${protocol}-api" $protocol "api-gateway"
}

Write-Host "All environments have been set up successfully!" 