# tests/websocket/performance/analyze-websocket-results.ps1

# =========================
# Script para analisar e comparar resultados de benchmark WebSocket
# =========================

# Diretório de resultados
$resultsDir = "tests/websocket/performance/results"
$apigwResults = "$resultsDir/ws-benchmark-apigw-result.txt"
$ingressResults = "$resultsDir/ws-benchmark-ingress-result.txt"

function Extract-BenchmarkData {
    param (
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "Arquivo não encontrado: $FilePath"
        return $null
    }
    
    $content = Get-Content -Path $FilePath -Raw
    
    # Extrair dados usando regex
    $data = @{}
    
    # Duração total
    if ($content -match "Duração total:\s+(\d+\.\d+)") {
        $data.Duration = [double]$matches[1]
    }
    
    # Taxa de conexões
    if ($content -match "Taxa de conexões:\s+(\d+\.\d+)") {
        $data.ConnectionsPerSecond = [double]$matches[1]
    } elseif ($content -match "Conexões/segundo:\s+(\d+\.\d+)") {
        $data.ConnectionsPerSecond = [double]$matches[1]
    }
    
    # Taxa de mensagens (se disponível)
    if ($content -match "Taxa de mensagens:\s+(\d+\.\d+)") {
        $data.MessagesPerSecond = [double]$matches[1]
    }
    
    # Conexões bem-sucedidas
    if ($content -match "Conexões sucesso:\s+(\d+)") {
        $data.SuccessfulConnections = [int]$matches[1]
    } elseif ($content -match "Bem-sucedidas:\s+(\d+)") {
        $data.SuccessfulConnections = [int]$matches[1]
    }
    
    # Taxa de sucesso
    if ($content -match "Taxa de sucesso:\s+(\d+\.\d+)") {
        $data.SuccessRate = [double]$matches[1]
    }
    
    # Latência média
    if ($content -match "Latência média \(conn\):\s+(\d+\.\d+)") {
        $data.AvgLatency = [double]$matches[1]
    } elseif ($content -match "Média:\s+(\d+\.\d+)") {
        $data.AvgLatency = [double]$matches[1]
    }
    
    # Latência média de mensagens (se disponível)
    if ($content -match "Latência média \(msg\):\s+(\d+\.\d+)") {
        $data.AvgMessageLatency = [double]$matches[1]
    }
    
    # Distribuição de latência
    if ($content -match "50% em (\d+\.\d+)") {
        $data.Latency50 = [double]$matches[1]
    }
    
    if ($content -match "90% em (\d+\.\d+)") {
        $data.Latency90 = [double]$matches[1]
    }
    
    if ($content -match "95% em (\d+\.\d+)") {
        $data.Latency95 = [double]$matches[1]
    }
    
    if ($content -match "99% em (\d+\.\d+)") {
        $data.Latency99 = [double]$matches[1]
    }
    
    # Para testes NodeJS
    if ($content -match "Mensagens enviadas:\s+(\d+)") {
        $data.MessagesSent = [int]$matches[1]
    }
    
    if ($content -match "Mensagens recebidas:\s+(\d+)") {
        $data.MessagesReceived = [int]$matches[1]
    }
    
    if ($content -match "Taxa de entrega:\s+(\d+\.\d+)") {
        $data.DeliveryRate = [double]$matches[1]
    }
    
    return $data
}

function Format-ComparisonTable {
    param (
        [PSCustomObject]$ApiGwData,
        [PSCustomObject]$IngressData
    )
    
    # Verificar se há dados
    if ($null -eq $ApiGwData -or $null -eq $IngressData) {
        Write-Warning "Não foi possível obter dados suficientes para análise. Certifique-se de que os arquivos de resultados existem."
        return
    }
    
    $isNodejsResults = $ApiGwData.PSObject.Properties.Name -contains "MessagesPerSecond"
    
    # Métricas comuns
    $metrics = @(
        @{Name = "Duração total (s)"; ApiGw = $ApiGwData.Duration; Ingress = $IngressData.Duration; Format = "F2"; HigherIsBetter = $false}
    )
    
    if ($isNodejsResults) {
        # Métricas para testes Node.js (WebSocket completo)
        $metrics += @(
            @{Name = "Conexões/segundo"; ApiGw = $ApiGwData.ConnectionsPerSecond; Ingress = $IngressData.ConnectionsPerSecond; Format = "F2"; HigherIsBetter = $true},
            @{Name = "Mensagens/segundo"; ApiGw = $ApiGwData.MessagesPerSecond; Ingress = $IngressData.MessagesPerSecond; Format = "F2"; HigherIsBetter = $true},
            @{Name = "Taxa de sucesso (%)"; ApiGw = $ApiGwData.SuccessRate; Ingress = $IngressData.SuccessRate; Format = "F2"; HigherIsBetter = $true},
            @{Name = "Taxa de entrega (%)"; ApiGw = $ApiGwData.DeliveryRate; Ingress = $IngressData.DeliveryRate; Format = "F2"; HigherIsBetter = $true},
            @{Name = "Latência média (conn) ms"; ApiGw = $ApiGwData.AvgLatency; Ingress = $IngressData.AvgLatency; Format = "F2"; HigherIsBetter = $false},
            @{Name = "Latência média (msg) ms"; ApiGw = $ApiGwData.AvgMessageLatency; Ingress = $IngressData.AvgMessageLatency; Format = "F2"; HigherIsBetter = $false},
            @{Name = "Latência P50 (ms)"; ApiGw = $ApiGwData.Latency50; Ingress = $IngressData.Latency50; Format = "F2"; HigherIsBetter = $false},
            @{Name = "Latência P90 (ms)"; ApiGw = $ApiGwData.Latency90; Ingress = $IngressData.Latency90; Format = "F2"; HigherIsBetter = $false},
            @{Name = "Latência P95 (ms)"; ApiGw = $ApiGwData.Latency95; Ingress = $IngressData.Latency95; Format = "F2"; HigherIsBetter = $false},
            @{Name = "Latência P99 (ms)"; ApiGw = $ApiGwData.Latency99; Ingress = $IngressData.Latency99; Format = "F2"; HigherIsBetter = $false}
        )
    } else {
        # Métricas para testes básicos (TCP)
        $metrics += @(
            @{Name = "Conexões/segundo"; ApiGw = $ApiGwData.ConnectionsPerSecond; Ingress = $IngressData.ConnectionsPerSecond; Format = "F2"; HigherIsBetter = $true},
            @{Name = "Conexões bem-sucedidas"; ApiGw = $ApiGwData.SuccessfulConnections; Ingress = $IngressData.SuccessfulConnections; Format = "N0"; HigherIsBetter = $true},
            @{Name = "Taxa de sucesso (%)"; ApiGw = $ApiGwData.SuccessRate; Ingress = $IngressData.SuccessRate; Format = "F2"; HigherIsBetter = $true},
            @{Name = "Latência média (ms)"; ApiGw = $ApiGwData.AvgLatency; Ingress = $IngressData.AvgLatency; Format = "F2"; HigherIsBetter = $false},
            @{Name = "Latência P50 (ms)"; ApiGw = $ApiGwData.Latency50; Ingress = $IngressData.Latency50; Format = "F2"; HigherIsBetter = $false},
            @{Name = "Latência P95 (ms)"; ApiGw = $ApiGwData.Latency95; Ingress = $IngressData.Latency95; Format = "F2"; HigherIsBetter = $false},
            @{Name = "Latência P99 (ms)"; ApiGw = $ApiGwData.Latency99; Ingress = $IngressData.Latency99; Format = "F2"; HigherIsBetter = $false}
        )
    }
    
    # Cabeçalho de tabela
    $headerFormat = "{0,-30} | {1,-15} | {2,-15} | {3,-12} | {4}"
    $separatorLine = "-" * 90
    
    Write-Host $separatorLine
    $header = $headerFormat -f "Métrica", "API Gateway", "Serviço Direto", "Diferença", "Melhor"
    Write-Host $header
    Write-Host $separatorLine
    
    # Linhas da tabela
    foreach ($metric in $metrics) {
        # Calcular diferença e determinar o melhor
        $diff = $metric.ApiGw - $metric.Ingress
        $percentDiff = if ($metric.Ingress -ne 0) { ($diff / $metric.Ingress) * 100 } else { 0 }
        
        # Determinar qual abordagem é melhor com base no sentido da métrica
        $betterApproach = ""
        if ([Math]::Abs($diff) -gt 0.01) {  # tolerância para evitar exibir diferenças insignificantes
            if ($metric.HigherIsBetter) {
                $betterApproach = if ($diff -gt 0) { "API Gateway" } else { "Serviço Direto" }
            } else {
                $betterApproach = if ($diff -lt 0) { "API Gateway" } else { "Serviço Direto" }
            }
        }
        
        # Determinar cor com base em qual é melhor
        $color = if ($betterApproach -eq "API Gateway") { "Yellow" } elseif ($betterApproach -eq "Serviço Direto") { "Green" } else { "Gray" }
        
        # Formatar valores
        $apiGwValueStr = "{0:$($metric.Format)}" -f $metric.ApiGw
        $ingressValueStr = "{0:$($metric.Format)}" -f $metric.Ingress
        
        # Formatar diferença
        $diffStr = if ([Math]::Abs($percentDiff) -gt 0.5) {
            $sign = if ($percentDiff -ge 0) { "+" } else { "" }
            "$sign{0:F2}%" -f $percentDiff
        } else {
            "≈ 0%"
        }
        
        # Formatar linha
        $line = $headerFormat -f $metric.Name, $apiGwValueStr, $ingressValueStr, $diffStr, $betterApproach
        Write-Host $line -ForegroundColor $color
    }
    
    Write-Host $separatorLine
}

# Extrair dados
$apigwData = Extract-BenchmarkData -FilePath $apigwResults
$ingressData = Extract-BenchmarkData -FilePath $ingressResults

if ($null -eq $apigwData -or $null -eq $ingressData) {
    Write-Host "Não foi possível analisar os resultados. Certifique-se de executar os testes de benchmark primeiro." -ForegroundColor Red
    exit
}

# Exibir resultados
Write-Host "`n==== ANÁLISE COMPARATIVA: API GATEWAY vs SERVIÇO DIRETO (WEBSOCKET) ====" -ForegroundColor Cyan
Format-ComparisonTable -ApiGwData $apigwData -IngressData $ingressData

# Conclusões
Write-Host "`n==== INTERPRETAÇÃO DOS RESULTADOS ====" -ForegroundColor Cyan

# Determinar latência média
$latencyDiffPercent = if ($ingressData.AvgLatency -ne 0) { 
    (($apigwData.AvgLatency - $ingressData.AvgLatency) / $ingressData.AvgLatency) * 100 
} else { 
    0 
}

# Determinar throughput
$throughputMetric = if ($apigwData.PSObject.Properties.Name -contains "MessagesPerSecond") {
    @{
        ApiGw = $apigwData.MessagesPerSecond
        Ingress = $ingressData.MessagesPerSecond
        Name = "mensagens por segundo"
    }
} else {
    @{
        ApiGw = $apigwData.ConnectionsPerSecond
        Ingress = $ingressData.ConnectionsPerSecond
        Name = "conexões por segundo"
    }
}

$throughputDiffPercent = if ($throughputMetric.Ingress -ne 0) { 
    (($throughputMetric.ApiGw - $throughputMetric.Ingress) / $throughputMetric.Ingress) * 100 
} else { 
    0 
}

# Conclusões sobre latência
if (([Math]::Abs($latencyDiffPercent)) -lt 5) {
    Write-Host "- Latência: As duas abordagens apresentam latência similar (diferença < 5%)" -ForegroundColor Cyan
} elseif ($latencyDiffPercent -gt 0) {
    Write-Host "- Latência: O Serviço Direto apresenta latência $([Math]::Abs($latencyDiffPercent).ToString("F1"))% menor que o API Gateway" -ForegroundColor Yellow
} else {
    Write-Host "- Latência: O API Gateway apresenta latência $([Math]::Abs($latencyDiffPercent).ToString("F1"))% menor que o Serviço Direto" -ForegroundColor Yellow
}

# Conclusões sobre throughput
if (([Math]::Abs($throughputDiffPercent)) -lt 5) {
    Write-Host "- Throughput: As duas abordagens apresentam $($throughputMetric.Name) similar (diferença < 5%)" -ForegroundColor Cyan
} elseif ($throughputDiffPercent -gt 0) {
    Write-Host "- Throughput: O API Gateway processa $([Math]::Abs($throughputDiffPercent).ToString("F1"))% mais $($throughputMetric.Name) que o Serviço Direto" -ForegroundColor Green
} else {
    Write-Host "- Throughput: O Serviço Direto processa $([Math]::Abs($throughputDiffPercent).ToString("F1"))% mais $($throughputMetric.Name) que o API Gateway" -ForegroundColor Green
}

# Conclusão final
Write-Host "`n==== CONCLUSÃO GERAL ====" -ForegroundColor Cyan

if ((([Math]::Abs($latencyDiffPercent)) -lt 10) -and (([Math]::Abs($throughputDiffPercent)) -lt 10)) {
    Write-Host "O desempenho das duas abordagens é similar (diferenças < 10%). A escolha pode ser baseada em outros fatores como segurança, gerenciamento e recursos adicionais oferecidos pelo API Gateway." -ForegroundColor White
} elseif (($latencyDiffPercent -gt 0) -and ($throughputDiffPercent -lt 0)) {
    # Serviço direto tem menor latência e maior throughput
    Write-Host "O Serviço Direto apresenta melhor desempenho geral, com menor latência e maior throughput. Recomendado para aplicações sensíveis a latência onde o gerenciamento de tráfego avançado não é prioridade." -ForegroundColor Green
} elseif (($latencyDiffPercent -lt 0) -and ($throughputDiffPercent -gt 0)) {
    # API gateway tem menor latência e maior throughput
    Write-Host "O API Gateway apresenta melhor desempenho geral, com menor latência e maior throughput. Além disso, oferece recursos adicionais de gerenciamento e segurança." -ForegroundColor Yellow
} else {
    # Trade-off
    if (([Math]::Abs($latencyDiffPercent)) -gt ([Math]::Abs($throughputDiffPercent))) {
        if ($latencyDiffPercent -gt 0) {
            Write-Host "O Serviço Direto oferece latência significativamente menor, podendo ser mais adequado para aplicações sensíveis a tempo de resposta. Considere o trade-off entre latência vs recursos de gerenciamento." -ForegroundColor Cyan
        } else {
            Write-Host "O API Gateway oferece latência significativamente menor, além de recursos adicionais de gerenciamento e segurança, sendo uma opção preferível para a maioria dos cenários." -ForegroundColor Cyan
        }
    } else {
        if ($throughputDiffPercent -gt 0) {
            Write-Host "O API Gateway oferece throughput significativamente maior, além de recursos adicionais de gerenciamento e segurança, sendo uma opção preferível para a maioria dos cenários." -ForegroundColor Cyan
        } else {
            Write-Host "O Serviço Direto oferece throughput significativamente maior, podendo ser mais adequado para aplicações com alto volume de mensagens. Considere o trade-off entre throughput vs recursos de gerenciamento." -ForegroundColor Cyan
        }
    }
}

# Sugestões
Write-Host "`n==== RECOMENDAÇÕES ====" -ForegroundColor Cyan
Write-Host "- Para aplicações sensíveis a latência: Prefira o método com menor latência (P95, P99)."
Write-Host "- Para aplicações com alto volume: Prefira o método com maior throughput (conexões/segundo ou mensagens/segundo)."
Write-Host "- Para aplicações corporativas: Considere usar o API Gateway pelos benefícios adicionais de segurança e gerenciamento."
Write-Host "- Para microsserviços internos: O acesso direto ao serviço pode ser adequado se a diferença de desempenho for significativa." 