#!/bin/bash

# Função para verificar e instalar dependências
check_dependencies() {
    echo "Checking and installing dependencies..."
    
    # Verificar se kubectl está instalado
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not found. Please install kubectl first."
        exit 1
    fi

    # Verificar se kind está instalado
    if ! command -v kind &> /dev/null; then
        echo "kind not found. Please install kind first."
        exit 1
    fi

    # Verificar se Docker está instalado e rodando
    if ! command -v docker &> /dev/null; then
        echo "Docker not found. Please install Docker first."
        exit 1
    fi

    # Verificar se Python está instalado
    if ! command -v python3 &> /dev/null; then
        echo "Python3 not found. Please install Python3 first."
        exit 1
    fi

    # Verificar e instalar dependências Python
    if [ -f "../requirements.txt" ]; then
        echo "Installing Python dependencies..."
        python3 -m pip install -r ../requirements.txt
    else
        echo "requirements.txt not found. Skipping Python dependencies."
    fi

    # Verificar e instalar ferramentas de teste
    echo "Checking test tools..."
    
    # Verificar hey
    if ! command -v hey &> /dev/null; then
        echo "hey not found. Installing..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
            chmod +x hey_linux_amd64
            sudo mv hey_linux_amd64 /usr/local/bin/hey
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install hey
        else
            echo "Unsupported OS for hey installation. Please install manually."
            exit 1
        fi
    fi

    # Verificar websocat
    if ! command -v websocat &> /dev/null; then
        echo "websocat not found. Installing..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            wget https://github.com/vi/websocat/releases/download/v1.11.0/websocat.x86_64-unknown-linux-musl
            chmod +x websocat.x86_64-unknown-linux-musl
            sudo mv websocat.x86_64-unknown-linux-musl /usr/local/bin/websocat
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install websocat
        else
            echo "Unsupported OS for websocat installation. Please install manually."
            exit 1
        fi
    fi

    # Verificar ghz
    if ! command -v ghz &> /dev/null; then
        echo "ghz not found. Installing..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            wget https://github.com/bojand/ghz/releases/download/v0.115.0/ghz-linux-x86_64.tar.gz
            tar -xzf ghz-linux-x86_64.tar.gz
            sudo mv ghz /usr/local/bin/
            rm ghz-linux-x86_64.tar.gz
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install ghz
        else
            echo "Unsupported OS for ghz installation. Please install manually."
            exit 1
        fi
    fi

    # Verificar bombardier
    if ! command -v bombardier &> /dev/null; then
        echo "bombardier not found. Installing..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            wget https://github.com/codesenberg/bombardier/releases/download/v1.2.6/bombardier-linux-amd64
            chmod +x bombardier-linux-amd64
            sudo mv bombardier-linux-amd64 /usr/local/bin/bombardier
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install bombardier
        else
            echo "Unsupported OS for bombardier installation. Please install manually."
            exit 1
        fi
    fi

    echo "All dependencies checked and installed successfully!"
}

# Função para criar namespace e aplicar manifestos
setup_environment() {
    local namespace=$1
    local protocol=$2
    local gateway_type=$3

    echo "Setting up $gateway_type environment for $protocol in namespace $namespace"
    
    # Criar namespace
    kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
    
    # Aplicar manifestos do serviço
    kubectl apply -f manifests/ingress-controller/$protocol/deployment.yaml -n $namespace
    
    # Aplicar manifestos específicos do tipo de gateway
    if [ "$gateway_type" = "ingress" ]; then
        kubectl apply -f manifests/ingress-controller/$protocol/ingress.yaml -n $namespace
    elif [ "$gateway_type" = "api-gateway" ]; then
        kubectl apply -f manifests/api-gateway/$protocol/deployment.yaml -n $namespace
    fi
    
    # Aguardar os pods estarem prontos
    kubectl wait --for=condition=ready pod -l app=${protocol}-service -n $namespace --timeout=300s
    if [ "$gateway_type" = "api-gateway" ]; then
        kubectl wait --for=condition=ready pod -l app=${protocol}-api-gateway -n $namespace --timeout=300s
    fi
}

# Verificar e instalar dependências antes de prosseguir
check_dependencies

# Criar ambientes para cada protocolo
protocols=("http" "https" "websocket" "graphql" "tcp")

# Criar ambientes com Ingress Controller
for protocol in "${protocols[@]}"; do
    setup_environment "${protocol}-ingress" "$protocol" "ingress"
done

# Criar ambientes com API Gateway
for protocol in "${protocols[@]}"; do
    setup_environment "${protocol}-api" "$protocol" "api-gateway"
done

echo "All environments have been set up successfully!" 