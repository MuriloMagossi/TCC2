#!/bin/bash

# Função para executar testes de carga
run_load_test() {
    local protocol=$1
    local gateway_type=$2
    local namespace=$3
    local duration=$4
    local connections=$5
    local output_file=$6

    echo "Running load test for $protocol using $gateway_type in namespace $namespace"
    
    # Obter o endereço do serviço
    local service_url
    if [ "$gateway_type" = "ingress" ]; then
        service_url="http://localhost:8080/$protocol"
    else
        service_url="http://localhost:8080/$protocol"
    fi

    # Executar teste de carga baseado no protocolo
    case $protocol in
        "http")
            hey -z $duration -c $connections -o csv $service_url > $output_file
            ;;
        "https")
            hey -z $duration -c $connections -o csv -k $service_url > $output_file
            ;;
        "websocket")
            # Usar uma ferramenta específica para WebSocket
            websocat -t $service_url > $output_file
            ;;
        "graphql")
            # Usar uma ferramenta específica para GraphQL
            ghz --insecure -z $duration -c $connections -o $output_file $service_url
            ;;
        "tcp")
            # Usar uma ferramenta específica para TCP
            bombardier -d $duration -c $connections $service_url > $output_file
            ;;
    esac
}

# Configurações de teste
DURATION="30s"
CONNECTIONS=100
RESULTS_DIR="test-results"

# Criar diretório de resultados
mkdir -p $RESULTS_DIR

# Executar testes para cada protocolo e tipo de gateway
protocols=("http" "https" "websocket" "graphql" "tcp")
gateway_types=("ingress" "api-gateway")

for protocol in "${protocols[@]}"; do
    for gateway_type in "${gateway_types[@]}"; do
        namespace="${protocol}-${gateway_type}"
        output_file="$RESULTS_DIR/${protocol}_${gateway_type}_results.csv"
        
        run_load_test $protocol $gateway_type $namespace $DURATION $CONNECTIONS $output_file
    done
done

echo "All tests completed. Results are available in $RESULTS_DIR" 