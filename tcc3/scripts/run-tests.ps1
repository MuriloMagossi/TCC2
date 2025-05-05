# Função para executar testes de carga
function Run-LoadTest {
    param (
        [string]$protocol,
        [string]$gateway_type,
        [string]$namespace,
        [string]$duration,
        [int]$connections,
        [string]$output_file
    )

    Write-Host "Running load test for $protocol using $gateway_type in namespace $namespace"
    
    # Obter o endereço do serviço
    $service_url = if ($gateway_type -eq "ingress") {
        "http://localhost:8080/$protocol"
    } else {
        "http://localhost:8080/$protocol"
    }

    # Executar teste de carga baseado no protocolo
    switch ($protocol) {
        "http" {
            .\hey.exe -z $duration -c $connections -o csv $service_url | Out-File -FilePath $output_file -Encoding utf8
        }
        "https" {
            .\hey.exe -z $duration -c $connections -o csv -k $service_url | Out-File -FilePath $output_file -Encoding utf8
        }
        "websocket" {
            # Usar websocat para WebSocket
            .\websocat.exe -t $service_url | Out-File -FilePath $output_file -Encoding utf8
        }
        "graphql" {
            # Usar ghz para GraphQL
            .\ghz.exe --insecure -z $duration -c $connections -o $output_file $service_url
        }
        "tcp" {
            # Usar bombardier para TCP
            .\bombardier.exe -d $duration -c $connections $service_url | Out-File -FilePath $output_file -Encoding utf8
        }
    }
}

# Configurações de teste
$DURATION = "30s"
$CONNECTIONS = 100
$RESULTS_DIR = "test-results"

# Criar diretório de resultados se não existir
if (-not (Test-Path $RESULTS_DIR)) {
    New-Item -ItemType Directory -Path $RESULTS_DIR | Out-Null
}

# Executar testes para cada protocolo e tipo de gateway
$protocols = @("http", "https", "websocket", "graphql", "tcp")
$gateway_types = @("ingress", "api-gateway")

foreach ($protocol in $protocols) {
    foreach ($gateway_type in $gateway_types) {
        $namespace = "${protocol}-${gateway_type}"
        $output_file = Join-Path $RESULTS_DIR "${protocol}_${gateway_type}_results.csv"
        
        Run-LoadTest -protocol $protocol -gateway_type $gateway_type -namespace $namespace -duration $DURATION -connections $CONNECTIONS -output_file $output_file
    }
}

Write-Host "All tests completed. Results are available in $RESULTS_DIR" 