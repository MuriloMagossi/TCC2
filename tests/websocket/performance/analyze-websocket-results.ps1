# tests/websocket/performance/analyze-websocket-results.ps1

# =========================
# Script para analisar e comparar resultados de benchmark WebSocket
# =========================

# Configurar encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Diretório de resultados
$resultsDir = "C:\Users\Murilo\Desktop\TCC2\tcc2\tests\websocket\performance\results"
$apigwResults = "$resultsDir\ws-benchmark-apigw-result.txt"
$ingressResults = "$resultsDir\ws-benchmark-ingress-result.txt"

function Get-BenchmarkData {
    param (
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "Arquivo não encontrado: $FilePath"
        return $null
    }
    
    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    
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
    
    return $data
}

function Format-ComparisonTable {
    param (
        [hashtable]$ApiGwData,
        [hashtable]$IngressData
    )
    
    # Definir métricas para comparação
    $metrics = @(
        @{Name = "Conexões/segundo"; ApiGw = $ApiGwData.ConnectionsPerSecond; Ingress = $IngressData.ConnectionsPerSecond; Format = "F2"; HigherIsBetter = $true},
        @{Name = "Taxa de sucesso (%)"; ApiGw = $ApiGwData.SuccessRate; Ingress = $IngressData.SuccessRate; Format = "F2"; HigherIsBetter = $true},
        @{Name = "Latência média (ms)"; ApiGw = $ApiGwData.AvgLatency; Ingress = $IngressData.AvgLatency; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latência P50 (ms)"; ApiGw = $ApiGwData.Latency50; Ingress = $IngressData.Latency50; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latência P95 (ms)"; ApiGw = $ApiGwData.Latency95; Ingress = $IngressData.Latency95; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latência P99 (ms)"; ApiGw = $ApiGwData.Latency99; Ingress = $IngressData.Latency99; Format = "F2"; HigherIsBetter = $false}
    )
    
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
        $percentDiff = if ($null -ne $metric.Ingress -and $metric.Ingress -ne 0) { 
            [double]($diff / $metric.Ingress) * 100 
        } else { 
            if ($null -ne $metric.ApiGw -and $metric.ApiGw -ne 0) { 100 } else { 0 }
        }
        
        # Determinar qual abordagem é melhor com base no sentido da métrica
        $betterApproach = ""
        if ($null -ne $metric.ApiGw -and $null -ne $metric.Ingress -and [Math]::Abs($percentDiff) -gt 0.01) {
            if ($metric.HigherIsBetter) {
                $betterApproach = if ($diff -gt 0) { "API Gateway" } else { "Serviço Direto" }
            } else {
                $betterApproach = if ($diff -lt 0) { "API Gateway" } else { "Serviço Direto" }
            }
        }
        
        # Determinar cor com base em qual é melhor
        $color = if ($betterApproach -eq "API Gateway") { "Yellow" } elseif ($betterApproach -eq "Serviço Direto") { "Green" } else { "Gray" }
        
        # Formatar valores
        $apiGwValueStr = if ($null -ne $metric.ApiGw) { "{0:$($metric.Format)}" -f $metric.ApiGw } else { "" }
        $ingressValueStr = if ($null -ne $metric.Ingress) { "{0:$($metric.Format)}" -f $metric.Ingress } else { "" }
        
        # Formatar diferença
        $diffStr = if ($null -ne $metric.ApiGw -and $null -ne $metric.Ingress -and [Math]::Abs([double]$percentDiff) -gt 0.5) {
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
$apigwData = Get-BenchmarkData -FilePath $apigwResults
$ingressData = Get-BenchmarkData -FilePath $ingressResults

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
$latencyDiffPercent = if ($null -ne $ingressData.AvgLatency -and $ingressData.AvgLatency -ne 0) { 
    (($apigwData.AvgLatency - $ingressData.AvgLatency) / $ingressData.AvgLatency) * 100 
} else { 
    if ($apigwData.AvgLatency -gt 0) { 100 } else { 0 }
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

$throughputDiffPercent = if ($null -ne $throughputMetric.Ingress -and $throughputMetric.Ingress -ne 0) { 
    (($throughputMetric.ApiGw - $throughputMetric.Ingress) / $throughputMetric.Ingress) * 100 
} else { 
    if ($throughputMetric.ApiGw -gt 0) { 100 } else { 0 }
}

# Conclusões sobre latência
if ([Math]::Abs([double]$latencyDiffPercent) -lt 5) {
    Write-Host "- Latência: As duas abordagens apresentam latência similar (diferença < 5%)" -ForegroundColor Cyan
} elseif ($latencyDiffPercent -gt 0) {
    Write-Host "- Latência: O Serviço Direto apresenta latência $([Math]::Abs([double]$latencyDiffPercent).ToString("F1"))% menor que o API Gateway" -ForegroundColor Yellow
} else {
    Write-Host "- Latência: O API Gateway apresenta latência $([Math]::Abs([double]$latencyDiffPercent).ToString("F1"))% menor que o Serviço Direto" -ForegroundColor Yellow
}

# Conclusões sobre throughput
if ([Math]::Abs([double]$throughputDiffPercent) -lt 5) {
    Write-Host "- Throughput: As duas abordagens apresentam throughput similar (diferença < 5%)" -ForegroundColor Cyan
} elseif ($throughputDiffPercent -gt 0) {
    Write-Host "- Throughput: O API Gateway processa $([Math]::Abs([double]$throughputDiffPercent).ToString("F1"))% mais $($throughputMetric.Name)" -ForegroundColor Yellow
} else {
    Write-Host "- Throughput: O Serviço Direto processa $([Math]::Abs([double]$throughputDiffPercent).ToString("F1"))% mais $($throughputMetric.Name)" -ForegroundColor Yellow
}

# Recomendações baseadas nos resultados
Write-Host "`n==== RECOMENDAÇÕES DE USO ====" -ForegroundColor Cyan

# Aplicações sensíveis à latência
Write-Host "`nPara aplicações sensíveis à latência (jogos, streaming, tempo real):"
if ([Math]::Abs([double]$latencyDiffPercent) -gt 10) {
    Write-Host "- Recomenda-se usar o Serviço Direto devido à menor latência" -ForegroundColor Yellow
} elseif ($latencyDiffPercent -lt -10) {
    Write-Host "- Recomenda-se usar o API Gateway devido à menor latência" -ForegroundColor Yellow
} else {
    Write-Host "- Ambas as abordagens são adequadas em termos de latência" -ForegroundColor Green
}

# Aplicações de alto volume
Write-Host "`nPara aplicações de alto volume (chat, notificações em massa):"
if ([Math]::Abs([double]$throughputDiffPercent) -gt 10) {
    Write-Host "- Recomenda-se usar o API Gateway devido ao maior throughput" -ForegroundColor Yellow
} elseif ($throughputDiffPercent -lt -10) {
    Write-Host "- Recomenda-se usar o Serviço Direto devido ao maior throughput" -ForegroundColor Yellow
} else {
    Write-Host "- Ambas as abordagens são adequadas em termos de throughput" -ForegroundColor Green
}

# Aplicações corporativas
Write-Host "`nPara aplicações corporativas (dashboards, monitoramento):"
Write-Host "- O API Gateway oferece benefícios adicionais:" -ForegroundColor Cyan
Write-Host "  * Melhor gerenciamento de autenticação e autorização"
Write-Host "  * Monitoramento e logging centralizados"
Write-Host "  * Controle de tráfego e políticas de segurança"

# Microsserviços internos
Write-Host "`nPara microsserviços internos:"
Write-Host "- O Serviço Direto é mais adequado:" -ForegroundColor Cyan
Write-Host "  * Menor overhead de rede"
Write-Host "  * Comunicação mais simples e direta"
Write-Host "  * Menor complexidade de configuração" 