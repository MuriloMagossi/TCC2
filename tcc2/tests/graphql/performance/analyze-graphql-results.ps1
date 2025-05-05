# tests/graphql/performance/analyze-graphql-results.ps1

# Configurar codificação para Windows-1252 (mais compatível com acentos em português no Windows)
$OutputEncoding = [System.Text.Encoding]::GetEncoding('Windows-1252')
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding('Windows-1252')
[Console]::InputEncoding = [System.Text.Encoding]::GetEncoding('Windows-1252')

# =========================
# Script para analisar e comparar resultados de benchmark GraphQL
# =========================

# Diretório de resultados
$resultsDir = "tests/graphql/performance/results"
$apigwResults = "$resultsDir/hey-graphql-apigw-result.txt"
$ingressResults = "$resultsDir/hey-graphql-ingress-result.txt"
$echoApigwResults = "$resultsDir/hey-graphql-echo-apigw-result.txt"
$echoIngressResults = "$resultsDir/hey-graphql-echo-ingress-result.txt"

function Get-HeyBenchmarkData {
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
    if ($content -match "Total:\s+(\d+\.\d+)\s+secs") {
        $data.Duration = [double]$matches[1]
    }
    
    # Tempos de resposta
    if ($content -match "Slowest:\s+(\d+\.\d+)\s+secs") {
        $data.Slowest = [double]$matches[1]
    }
    
    if ($content -match "Fastest:\s+(\d+\.\d+)\s+secs") {
        $data.Fastest = [double]$matches[1]
    }
    
    if ($content -match "Average:\s+(\d+\.\d+)\s+secs") {
        $data.Average = [double]$matches[1]
    }
    
    # Requisições por segundo
    if ($content -match "Requests/sec:\s+(\d+\.\d+)") {
        $data.RequestsPerSecond = [double]$matches[1]
    }
    
    # Dados transferidos
    if ($content -match "Total data:\s+(\d+)\s+bytes") {
        $data.TotalData = [int]$matches[1]
    }
    
    if ($content -match "Size/request:\s+(\d+)\s+bytes") {
        $data.SizePerRequest = [int]$matches[1]
    }
    
    # Distribuição de latência
    if ($content -match "10% in (\d+\.\d+) secs") {
        $data.Latency10 = [double]$matches[1]
    }
    
    if ($content -match "25% in (\d+\.\d+) secs") {
        $data.Latency25 = [double]$matches[1]
    }
    
    if ($content -match "50% in (\d+\.\d+) secs") {
        $data.Latency50 = [double]$matches[1]
    }
    
    if ($content -match "75% in (\d+\.\d+) secs") {
        $data.Latency75 = [double]$matches[1]
    }
    
    if ($content -match "90% in (\d+\.\d+) secs") {
        $data.Latency90 = [double]$matches[1]
    }
    
    if ($content -match "95% in (\d+\.\d+) secs") {
        $data.Latency95 = [double]$matches[1]
    }
    
    if ($content -match "99% in (\d+\.\d+) secs") {
        $data.Latency99 = [double]$matches[1]
    }
    
    # Detalhes das fases da requisição
    if ($content -match "DNS\+dialup:\s+(\d+\.\d+) secs") {
        $data.DNSDialup = [double]$matches[1]
    }
    
    if ($content -match "DNS-lookup:\s+(\d+\.\d+) secs") {
        $data.DNSLookup = [double]$matches[1]
    }
    
    if ($content -match "req write:\s+(\d+\.\d+) secs") {
        $data.ReqWrite = [double]$matches[1]
    }
    
    if ($content -match "resp wait:\s+(\d+\.\d+) secs") {
        $data.RespWait = [double]$matches[1]
    }
    
    if ($content -match "resp read:\s+(\d+\.\d+) secs") {
        $data.RespRead = [double]$matches[1]
    }
    
    # Status codes
    $statusCodeMatches = [regex]::Matches($content, "\[(\d+)\]\s+(\d+) responses")
    if ($statusCodeMatches.Count -gt 0) {
        $data.StatusCodes = @{}
        foreach ($match in $statusCodeMatches) {
            $code = $match.Groups[1].Value
            $count = [int]$match.Groups[2].Value
            $data.StatusCodes[$code] = $count
        }
        $data.TotalResponses = ($data.StatusCodes.Values | Measure-Object -Sum).Sum
    }
    
    return $data
}

function Format-ComparisonTable {
    param (
        [string]$Title,
        [PSCustomObject]$Data1,
        [string]$Label1,
        [PSCustomObject]$Data2,
        [string]$Label2
    )
    
    # Verificar se há dados
    if ($null -eq $Data1 -or $null -eq $Data2) {
        Write-Warning "Não foi possível obter dados suficientes para análise. Certifique-se de que os arquivos de resultados existem."
        return
    }
    
    # Métricas comuns para testes com hey
    $metrics = @(
        @{Name = "Duração total (s)"; Data1 = $Data1.Duration; Data2 = $Data2.Duration; Format = "F2"; HigherIsBetter = $false}
        @{Name = "Requisições/segundo"; Data1 = $Data1.RequestsPerSecond; Data2 = $Data2.RequestsPerSecond; Format = "F2"; HigherIsBetter = $true}
        @{Name = "Tempo médio (s)"; Data1 = $Data1.Average; Data2 = $Data2.Average; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Mais rápido (s)"; Data1 = $Data1.Fastest; Data2 = $Data2.Fastest; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Mais lento (s)"; Data1 = $Data1.Slowest; Data2 = $Data2.Slowest; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Latência P50 (s)"; Data1 = $Data1.Latency50; Data2 = $Data2.Latency50; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Latência P90 (s)"; Data1 = $Data1.Latency90; Data2 = $Data2.Latency90; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Latência P95 (s)"; Data1 = $Data1.Latency95; Data2 = $Data2.Latency95; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Latência P99 (s)"; Data1 = $Data1.Latency99; Data2 = $Data2.Latency99; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Total de respostas"; Data1 = $Data1.TotalResponses; Data2 = $Data2.TotalResponses; Format = "N0"; HigherIsBetter = $true}
        @{Name = "Tempo espera resp (s)"; Data1 = $Data1.RespWait; Data2 = $Data2.RespWait; Format = "F4"; HigherIsBetter = $false}
    )
    
    # Cabeçalho de tabela
    $headerFormat = "{0,-25} | {1,-15} | {2,-15} | {3,-12} | {4}"
    $separatorLine = "-" * 90
    
    Write-Host "$Title" -ForegroundColor Cyan
    Write-Host $separatorLine
    $header = $headerFormat -f "Métrica", $Label1, $Label2, "Diferença", "Melhor"
    Write-Host $header
    Write-Host $separatorLine
    
    # Linhas da tabela
    foreach ($metric in $metrics) {
        # Calcular diferença e determinar o melhor
        $diff = $metric.Data1 - $metric.Data2
        $percentDiff = if (($null -ne $metric.Data2) -and ($metric.Data2 -ne 0)) { 
            ($diff / $metric.Data2) * 100 
        } else { 
            0 
        }
        
        # Determinar qual abordagem é melhor com base no sentido da métrica
        $betterApproach = ""
        if (($null -ne $diff) -and ([Math]::Abs([double]$diff) -gt 0.01)) {  # tolerância para evitar exibir diferenças insignificantes
            if ($metric.HigherIsBetter) {
                $betterApproach = if ($diff -gt 0) { $Label1 } else { $Label2 }
            } else {
                $betterApproach = if ($diff -lt 0) { $Label1 } else { $Label2 }
            }
        }
        
        # Determinar cor com base em qual é melhor
        $color = if ($betterApproach -eq $Label1) { "Yellow" } elseif ($betterApproach -eq $Label2) { "Green" } else { "Gray" }
        
        # Formatar valores
        $data1ValueStr = if ($null -ne $metric.Data1) { "{0:$($metric.Format)}" -f $metric.Data1 } else { "N/A" }
        $data2ValueStr = if ($null -ne $metric.Data2) { "{0:$($metric.Format)}" -f $metric.Data2 } else { "N/A" }
        
        # Formatar diferença
        $diffStr = if (($null -ne $percentDiff) -and ([Math]::Abs([double]$percentDiff) -gt 0.5)) {
            $sign = if ($percentDiff -ge 0) { "+" } else { "" }
            "$sign{0:F2}%" -f $percentDiff
        } else {
            "≈ 0%"
        }
        
        # Formatar linha
        $line = $headerFormat -f $metric.Name, $data1ValueStr, $data2ValueStr, $diffStr, $betterApproach
        Write-Host $line -ForegroundColor $color
    }
    
    Write-Host $separatorLine
    Write-Host ""
}

# Extrair dados dos testes normais e de echo
$apigwData = Get-HeyBenchmarkData -FilePath $apigwResults
$ingressData = Get-HeyBenchmarkData -FilePath $ingressResults
$echoApigwData = Get-HeyBenchmarkData -FilePath $echoApigwResults
$echoIngressData = Get-HeyBenchmarkData -FilePath $echoIngressResults

# Verificar se temos todos os dados necessários
$missingFiles = @()
if ($null -eq $apigwData) { $missingFiles += $apigwResults }
if ($null -eq $ingressData) { $missingFiles += $ingressResults }
if ($null -eq $echoApigwData) { $missingFiles += $echoApigwResults }
if ($null -eq $echoIngressData) { $missingFiles += $echoIngressResults }

if ($missingFiles.Count -gt 0) {
    Write-Host "Não foi possível analisar todos os resultados. Os seguintes arquivos estão faltando:" -ForegroundColor Red
    foreach ($file in $missingFiles) {
        Write-Host "  - $file" -ForegroundColor Red
    }
    Write-Host "Por favor, execute os testes de benchmark primeiro." -ForegroundColor Red
    exit
}

# Exibir resultados comparativos
Write-Host "`n==== ANÁLISE COMPARATIVA: API GATEWAY vs SERVIÇO DIRETO (GRAPHQL) ====" -ForegroundColor Cyan

# Comparação 1: API Gateway vs Serviço Direto (GraphQL completo)
Format-ComparisonTable -Title "`n=== Comparação GraphQL: API Gateway vs Serviço Direto ===" -Data1 $apigwData -Label1 "API Gateway" -Data2 $ingressData -Label2 "Serviço Direto"

# Comparação 2: API Gateway vs Serviço Direto (Echo - baixo processamento)
Format-ComparisonTable -Title "`n=== Comparação GraphQL Echo: API Gateway vs Serviço Direto ===" -Data1 $echoApigwData -Label1 "API Gateway" -Data2 $echoIngressData -Label2 "Serviço Direto"

# Comparação 3: Processamento vs Echo no API Gateway
Format-ComparisonTable -Title "`n=== Comparação no API Gateway: GraphQL vs Echo ===" -Data1 $apigwData -Label1 "GraphQL" -Data2 $echoApigwData -Label2 "Echo"

# Comparação 4: Processamento vs Echo no Serviço Direto
Format-ComparisonTable -Title "`n=== Comparação no Serviço Direto: GraphQL vs Echo ===" -Data1 $ingressData -Label1 "GraphQL" -Data2 $echoIngressData -Label2 "Echo"

# Conclusões
Write-Host "`n==== INTERPRETAÇÃO DOS RESULTADOS ====" -ForegroundColor Cyan

# Calcular diferenças percentuais para métricas chave
$latencyDiffPercent = if (($null -ne $ingressData.Average) -and ($ingressData.Average -ne 0)) { 
    (($apigwData.Average - $ingressData.Average) / $ingressData.Average) * 100 
} else { 
    0 
}

$throughputDiffPercent = if (($null -ne $ingressData.RequestsPerSecond) -and ($ingressData.RequestsPerSecond -ne 0)) { 
    (($apigwData.RequestsPerSecond - $ingressData.RequestsPerSecond) / $ingressData.RequestsPerSecond) * 100 
} else { 
    0 
}

# Conclusão sobre latência
if (($null -ne $latencyDiffPercent) -and ([Math]::Abs([double]$latencyDiffPercent)) -lt 5) {
    Write-Host "- Latência: As duas abordagens apresentam latência similar (diferença < 5%)" -ForegroundColor Cyan
} elseif (($null -ne $latencyDiffPercent) -and ($latencyDiffPercent -gt 0)) {
    Write-Host "- Latência: O Serviço Direto apresenta latência $([Math]::Abs([double]$latencyDiffPercent).ToString("F1"))% menor que o API Gateway" -ForegroundColor Yellow
} else {
    Write-Host "- Latência: O API Gateway apresenta latência $([Math]::Abs([double]$latencyDiffPercent).ToString("F1"))% menor que o Serviço Direto" -ForegroundColor Yellow
}

# Conclusão sobre throughput
if (($null -ne $throughputDiffPercent) -and ([Math]::Abs([double]$throughputDiffPercent)) -lt 5) {
    Write-Host "- Throughput: As duas abordagens apresentam taxa de requisições similar (diferença < 5%)" -ForegroundColor Cyan
} elseif (($null -ne $throughputDiffPercent) -and ($throughputDiffPercent -gt 0)) {
    Write-Host "- Throughput: O API Gateway processa $([Math]::Abs([double]$throughputDiffPercent).ToString("F1"))% mais requisições por segundo que o Serviço Direto" -ForegroundColor Green
} else {
    Write-Host "- Throughput: O Serviço Direto processa $([Math]::Abs([double]$throughputDiffPercent).ToString("F1"))% mais requisições por segundo que o API Gateway" -ForegroundColor Green
}

# Calcular overhead do API Gateway
$echoLatencyDiffPercent = if (($null -ne $echoIngressData.Average) -and ($echoIngressData.Average -ne 0)) { 
    (($echoApigwData.Average - $echoIngressData.Average) / $echoIngressData.Average) * 100 
} else { 
    0 
}

Write-Host "- Overhead do API Gateway: No teste Echo (baixo processamento), o API Gateway adiciona aproximadamente $([Math]::Abs([double]$echoLatencyDiffPercent).ToString("F1"))% de latência adicional" -ForegroundColor Cyan

# Conclusão final
Write-Host "`n==== CONCLUSÃO GERAL ====" -ForegroundColor Cyan

if ((($null -ne $latencyDiffPercent) -and ([Math]::Abs([double]$latencyDiffPercent)) -lt 10) -and (($null -ne $throughputDiffPercent) -and ([Math]::Abs([double]$throughputDiffPercent)) -lt 10)) {
    Write-Host "O desempenho das duas abordagens é similar para GraphQL (diferenças < 10%). A escolha pode ser baseada em outros fatores como segurança, gerenciamento e recursos adicionais oferecidos pelo API Gateway." -ForegroundColor White
} elseif (($latencyDiffPercent -gt 0) -and ($throughputDiffPercent -lt 0)) {
    # Serviço direto tem menor latência e maior throughput
    Write-Host "O Serviço Direto apresenta melhor desempenho geral para GraphQL, com menor latência e maior throughput. Recomendado para aplicações sensíveis a latência onde o gerenciamento de tráfego avançado não é prioridade." -ForegroundColor Green
} elseif (($latencyDiffPercent -lt 0) -and ($throughputDiffPercent -gt 0)) {
    # API gateway tem menor latência e maior throughput
    Write-Host "O API Gateway apresenta melhor desempenho geral para GraphQL, com menor latência e maior throughput. Além disso, oferece recursos adicionais de gerenciamento e segurança." -ForegroundColor Yellow
} else {
    # Trade-off
    if (([Math]::Abs([double]$latencyDiffPercent)) -gt ([Math]::Abs([double]$throughputDiffPercent))) {
        if ($latencyDiffPercent -gt 0) {
            Write-Host "O Serviço Direto oferece latência significativamente menor para GraphQL, podendo ser mais adequado para aplicações sensíveis a tempo de resposta. Considere o trade-off entre latência vs recursos de gerenciamento." -ForegroundColor Cyan
        } else {
            Write-Host "O API Gateway oferece latência significativamente menor para GraphQL, além de recursos adicionais de gerenciamento e segurança, sendo uma opção preferível para a maioria dos cenários." -ForegroundColor Cyan
        }
    } else {
        if ($throughputDiffPercent -gt 0) {
            Write-Host "O API Gateway oferece throughput significativamente maior para GraphQL, além de recursos adicionais de gerenciamento e segurança, sendo uma opção preferível para a maioria dos cenários." -ForegroundColor Cyan
        } else {
            Write-Host "O Serviço Direto oferece throughput significativamente maior para GraphQL, podendo ser mais adequado para aplicações com alto volume de requisições. Considere o trade-off entre throughput vs recursos de gerenciamento." -ForegroundColor Cyan
        }
    }
}

# Sugestões
Write-Host "`n==== RECOMENDAÇÕES ====" -ForegroundColor Cyan
Write-Host "- Para aplicações sensíveis a latência: Prefira o método com menor latência (P95, P99)."
Write-Host "- Para aplicações com alto volume: Prefira o método com maior throughput (requisições/segundo)."
Write-Host "- Para aplicações corporativas: Considere usar o API Gateway pelos benefícios adicionais de segurança e gerenciamento."
Write-Host "- Para microsserviços internos: O acesso direto ao serviço pode ser adequado se a diferença de desempenho for significativa." 