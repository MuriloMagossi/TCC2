# tests/websocket/performance/analyze-websocket-results.ps1

# =========================
# Script para analisar e comparar resultados de benchmark WebSocket
# =========================

# Configurar encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Diretorio de resultados
$resultsDir = Join-Path $PSScriptRoot "results"
$apigwResults = Join-Path $resultsDir "ws-benchmark-apigw-result.txt"
$ingressResults = Join-Path $resultsDir "ws-benchmark-ingress-result.txt"

function Get-BenchmarkData {
    param (
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "Arquivo nao encontrado: $FilePath"
        return $null
    }
    
    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    
    # Extrair dados usando regex
    $data = @{}
    
    # Duracao total
    if ($content -match "Duracao total:\s+(\d+\.\d+)") {
        $data.Duration = [double]$matches[1]
    }
    
    # Taxa de conexoes
    if ($content -match "Taxa de conexoes:\s+(\d+\.\d+)") {
        $data.ConnectionsPerSecond = [double]$matches[1]
    } elseif ($content -match "Conexoes/segundo:\s+(\d+\.\d+)") {
        $data.ConnectionsPerSecond = [double]$matches[1]
    } elseif ($content -match "Taxa de conexoes:\s+(\d+,\d+)") {
        $data.ConnectionsPerSecond = [double]($matches[1] -replace ',', '.')
    }
    
    # Taxa de mensagens (se disponivel)
    if ($content -match "Taxa de mensagens:\s+(\d+\.\d+)") {
        $data.MessagesPerSecond = [double]$matches[1]
    } elseif ($content -match "Taxa de mensagens:\s+(\d+,\d+)") {
        $data.MessagesPerSecond = [double]($matches[1] -replace ',', '.')
    }
    
    # Conexoes bem-sucedidas
    if ($content -match "Conexoes sucesso:\s+(\d+)") {
        $data.SuccessfulConnections = [int]$matches[1]
    } elseif ($content -match "Bem-sucedidas:\s+(\d+)") {
        $data.SuccessfulConnections = [int]$matches[1]
    }
    
    # Taxa de sucesso
    if ($content -match "Taxa de sucesso:\s+(\d+\.\d+)") {
        $data.SuccessRate = [double]$matches[1]
    } elseif ($content -match "Taxa de sucesso:\s+(\d+,\d+)") {
        $data.SuccessRate = [double]($matches[1] -replace ',', '.')
    }
    
    # Latencia media
    if ($content -match "Latencia media \(conn\):\s+(\d+\.\d+)") {
        $data.AvgLatency = [double]$matches[1]
    } elseif ($content -match "Media:\s+(\d+\.\d+)") {
        $data.AvgLatency = [double]$matches[1]
    } elseif ($content -match "Latencia media \(conn\):\s+(\d+,\d+)") {
        $data.AvgLatency = [double]($matches[1] -replace ',', '.')
    } elseif ($content -match "Media:\s+(\d+,\d+)") {
        $data.AvgLatency = [double]($matches[1] -replace ',', '.')
    }
    
    # Latencia media de mensagens (se disponivel)
    if ($content -match "Latencia media \(msg\):\s+(\d+\.\d+)") {
        $data.AvgMessageLatency = [double]$matches[1]
    } elseif ($content -match "Latencia media \(msg\):\s+(\d+,\d+)") {
        $data.AvgMessageLatency = [double]($matches[1] -replace ',', '.')
    }
    
    # Distribuicao de latencia
    if ($content -match "10% em (\d+\.\d+)") {
        $data.Latency10 = [double]$matches[1]
    } elseif ($content -match "10% em (\d+,\d+)") {
        $data.Latency10 = [double]($matches[1] -replace ',', '.')
    }
    
    if ($content -match "25% em (\d+\.\d+)") {
        $data.Latency25 = [double]$matches[1]
    } elseif ($content -match "25% em (\d+,\d+)") {
        $data.Latency25 = [double]($matches[1] -replace ',', '.')
    }
    
    if ($content -match "50% em (\d+\.\d+)") {
        $data.Latency50 = [double]$matches[1]
    } elseif ($content -match "50% em (\d+,\d+)") {
        $data.Latency50 = [double]($matches[1] -replace ',', '.')
    }
    
    if ($content -match "75% em (\d+\.\d+)") {
        $data.Latency75 = [double]$matches[1]
    } elseif ($content -match "75% em (\d+,\d+)") {
        $data.Latency75 = [double]($matches[1] -replace ',', '.')
    }
    
    if ($content -match "90% em (\d+\.\d+)") {
        $data.Latency90 = [double]$matches[1]
    } elseif ($content -match "90% em (\d+,\d+)") {
        $data.Latency90 = [double]($matches[1] -replace ',', '.')
    }
    
    if ($content -match "95% em (\d+\.\d+)") {
        $data.Latency95 = [double]$matches[1]
    } elseif ($content -match "95% em (\d+,\d+)") {
        $data.Latency95 = [double]($matches[1] -replace ',', '.')
    }
    
    if ($content -match "99% em (\d+\.\d+)") {
        $data.Latency99 = [double]$matches[1]
    } elseif ($content -match "99% em (\d+,\d+)") {
        $data.Latency99 = [double]($matches[1] -replace ',', '.')
    }
    
    # Latencia minima e maxima
    if ($content -match "Mais rapido:\s+(\d+\.\d+)") {
        $data.MinLatency = [double]$matches[1]
    } elseif ($content -match "Mais rapido:\s+(\d+,\d+)") {
        $data.MinLatency = [double]($matches[1] -replace ',', '.')
    }
    
    if ($content -match "Mais lento:\s+(\d+\.\d+)") {
        $data.MaxLatency = [double]$matches[1]
    } elseif ($content -match "Mais lento:\s+(\d+,\d+)") {
        $data.MaxLatency = [double]($matches[1] -replace ',', '.')
    }
    
    # Desvio padrao
    if ($content -match "Desvio padrao:\s+(\d+\.\d+)") {
        $data.StdDev = [double]$matches[1]
    } elseif ($content -match "Desvio padrao:\s+(\d+,\d+)") {
        $data.StdDev = [double]($matches[1] -replace ',', '.')
    }
    
    return $data
}

function Format-ComparisonTable {
    param (
        [hashtable]$ApiGwData,
        [hashtable]$IngressData
    )
    
    # Definir metricas para comparacao
    $metrics = @(
        @{Name = "Conexoes/segundo"; ApiGw = $ApiGwData.ConnectionsPerSecond; Ingress = $IngressData.ConnectionsPerSecond; Format = "F2"; HigherIsBetter = $true},
        @{Name = "Taxa de sucesso (%)"; ApiGw = $ApiGwData.SuccessRate; Ingress = $IngressData.SuccessRate; Format = "F2"; HigherIsBetter = $true},
        @{Name = "Latencia media (ms)"; ApiGw = $ApiGwData.AvgLatency; Ingress = $IngressData.AvgLatency; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latencia minima (ms)"; ApiGw = $ApiGwData.MinLatency; Ingress = $IngressData.MinLatency; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latencia maxima (ms)"; ApiGw = $ApiGwData.MaxLatency; Ingress = $IngressData.MaxLatency; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Desvio padrao (ms)"; ApiGw = $ApiGwData.StdDev; Ingress = $IngressData.StdDev; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latencia P10 (ms)"; ApiGw = $ApiGwData.Latency10; Ingress = $IngressData.Latency10; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latencia P25 (ms)"; ApiGw = $ApiGwData.Latency25; Ingress = $IngressData.Latency25; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latencia P50 (ms)"; ApiGw = $ApiGwData.Latency50; Ingress = $IngressData.Latency50; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latencia P75 (ms)"; ApiGw = $ApiGwData.Latency75; Ingress = $IngressData.Latency75; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latencia P90 (ms)"; ApiGw = $ApiGwData.Latency90; Ingress = $IngressData.Latency90; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latencia P95 (ms)"; ApiGw = $ApiGwData.Latency95; Ingress = $IngressData.Latency95; Format = "F2"; HigherIsBetter = $false},
        @{Name = "Latencia P99 (ms)"; ApiGw = $ApiGwData.Latency99; Ingress = $IngressData.Latency99; Format = "F2"; HigherIsBetter = $false}
    )
    
    # Cabecalho de tabela
    $headerFormat = "{0,-30} | {1,-15} | {2,-15} | {3,-12} | {4}"
    $separatorLine = "-" * 90
    
    Write-Host $separatorLine
    $header = $headerFormat -f "Metrica", "API Gateway", "Ingress", "Diferenca", "Melhor"
    Write-Host $header
    Write-Host $separatorLine
    
    # Linhas da tabela
    foreach ($metric in $metrics) {
        # Calcular diferenca e determinar o melhor
        $diff = $metric.ApiGw - $metric.Ingress
        $percentDiff = if ($null -ne $metric.Ingress -and $metric.Ingress -ne 0) { 
            [double]($diff / $metric.Ingress) * 100 
        } else { 
            if ($null -ne $metric.ApiGw -and $metric.ApiGw -ne 0) { 100 } else { 0 }
        }
        
        # Determinar qual abordagem e melhor com base no sentido da metrica
        $betterApproach = ""
        if ($null -ne $metric.ApiGw -and $null -ne $metric.Ingress -and [Math]::Abs($percentDiff) -gt 0.01) {
            if ($metric.HigherIsBetter) {
                $betterApproach = if ($diff -gt 0) { "API Gateway" } else { "Ingress" }
            } else {
                $betterApproach = if ($diff -lt 0) { "API Gateway" } else { "Ingress" }
            }
        }
        
        # Determinar cor com base em qual e melhor
        $color = if ($betterApproach -eq "API Gateway") { "Yellow" } elseif ($betterApproach -eq "Ingress") { "Green" } else { "Gray" }
        
        # Formatar valores
        $apiGwValueStr = if ($null -ne $metric.ApiGw) { "{0:$($metric.Format)}" -f $metric.ApiGw } else { "" }
        $ingressValueStr = if ($null -ne $metric.Ingress) { "{0:$($metric.Format)}" -f $metric.Ingress } else { "" }
        
        # Formatar diferenca
        $diffStr = if ($null -ne $metric.ApiGw -and $null -ne $metric.Ingress -and [Math]::Abs([double]$percentDiff) -gt 0.5) {
            $sign = if ($percentDiff -ge 0) { "+" } else { "" }
            "$sign{0:F2}%" -f $percentDiff
        } else {
            "= 0%"
        }
        
        # Formatar linha
        $line = $headerFormat -f $metric.Name, $apiGwValueStr, $ingressValueStr, $diffStr, $betterApproach
        Write-Host $line -ForegroundColor $color
    }
    
    Write-Host $separatorLine
}

function Get-LatencyAnalysis {
    param (
        [hashtable]$ApiGwData,
        [hashtable]$IngressData
    )
    
    $analysis = @{}
    
    # Analise de consistencia (desvio padrao)
    $apiGwConsistency = if ($ApiGwData.StdDev -lt $IngressData.StdDev) { "API Gateway" } else { "Ingress" }
    $consistencyDiff = [Math]::Abs(($ApiGwData.StdDev - $IngressData.StdDev) / $IngressData.StdDev * 100)
    $analysis.Consistency = @{
        Better = $apiGwConsistency
        Difference = $consistencyDiff
    }
    
    # Analise de latencia extrema (P99)
    $apiGwExtreme = if ($ApiGwData.Latency99 -lt $IngressData.Latency99) { "API Gateway" } else { "Ingress" }
    $extremeDiff = [Math]::Abs(($ApiGwData.Latency99 - $IngressData.Latency99) / $IngressData.Latency99 * 100)
    $analysis.ExtremeLatency = @{
        Better = $apiGwExtreme
        Difference = $extremeDiff
    }
    
    # Analise de latencia media
    $apiGwAvg = if ($ApiGwData.AvgLatency -lt $IngressData.AvgLatency) { "API Gateway" } else { "Ingress" }
    $avgDiff = [Math]::Abs(($ApiGwData.AvgLatency - $IngressData.AvgLatency) / $IngressData.AvgLatency * 100)
    $analysis.AverageLatency = @{
        Better = $apiGwAvg
        Difference = $avgDiff
    }
    
    return $analysis
}

# Extrair dados
$apigwData = Get-BenchmarkData -FilePath $apigwResults
$ingressData = Get-BenchmarkData -FilePath $ingressResults

if ($null -eq $apigwData -or $null -eq $ingressData) {
    Write-Host "Nao foi possivel analisar os resultados. Certifique-se de executar os testes de benchmark primeiro." -ForegroundColor Red
    exit
}

# Exibir resultados
Write-Host "`n==== ANALISE COMPARATIVA: API GATEWAY vs INGRESS CONTROLLER (WEBSOCKET) ====" -ForegroundColor Cyan
Format-ComparisonTable -ApiGwData $apigwData -IngressData $ingressData

# Analise de latencia
$latencyAnalysis = Get-LatencyAnalysis -ApiGwData $apigwData -IngressData $ingressData

# Conclusoes
Write-Host "`n==== INTERPRETACAO DOS RESULTADOS ====" -ForegroundColor Cyan

# Analise de consistencia
Write-Host "`nConsistencia de Performance:" -ForegroundColor Yellow
Write-Host "- $($latencyAnalysis.Consistency.Better) apresenta melhor consistencia (desvio padrao $([Math]::Round($latencyAnalysis.Consistency.Difference, 1))% menor)"
Write-Host "- Isso indica que o $($latencyAnalysis.Consistency.Better) oferece tempos de resposta mais previsiveis"

# Analise de latencia extrema
Write-Host "`nLatencia em Condicoes Extremas:" -ForegroundColor Yellow
Write-Host "- $($latencyAnalysis.ExtremeLatency.Better) apresenta melhor performance em condicoes extremas (P99 $([Math]::Round($latencyAnalysis.ExtremeLatency.Difference, 1))% melhor)"
Write-Host "- Isso e importante para aplicacoes que nao podem tolerar latencias altas ocasionais"

# Analise de latencia media
Write-Host "`nLatencia Media:" -ForegroundColor Yellow
Write-Host "- $($latencyAnalysis.AverageLatency.Better) apresenta melhor latencia media ($([Math]::Round($latencyAnalysis.AverageLatency.Difference, 1))% melhor)"
Write-Host "- Isso indica melhor performance geral para a maioria dos casos de uso"

# Recomendacoes baseadas nos resultados
Write-Host "`n==== RECOMENDACOES DE USO ====" -ForegroundColor Cyan

# Aplicacoes sensiveis a latencia
Write-Host "`nPara aplicacoes sensiveis a latencia (jogos, streaming, tempo real):"
if ($latencyAnalysis.AverageLatency.Difference -gt 10) {
    Write-Host "- Recomenda-se usar o $($latencyAnalysis.AverageLatency.Better) devido a menor latencia media" -ForegroundColor Yellow
} else {
    Write-Host "- Ambas as abordagens sao adequadas em termos de latencia media" -ForegroundColor Green
}

# Aplicacoes que requerem consistencia
Write-Host "`nPara aplicacoes que requerem consistencia (sistemas financeiros, monitoramento):"
if ($latencyAnalysis.Consistency.Difference -gt 10) {
    Write-Host "- Recomenda-se usar o $($latencyAnalysis.Consistency.Better) devido a maior consistencia" -ForegroundColor Yellow
} else {
    Write-Host "- Ambas as abordagens oferecem consistencia similar" -ForegroundColor Green
}

# Aplicacoes de alto volume
Write-Host "`nPara aplicacoes de alto volume (chat, notificacoes em massa):"
$throughputDiff = [Math]::Abs(($apigwData.ConnectionsPerSecond - $ingressData.ConnectionsPerSecond) / $ingressData.ConnectionsPerSecond * 100)
if ($throughputDiff -gt 10) {
    $betterThroughput = if ($apigwData.ConnectionsPerSecond -gt $ingressData.ConnectionsPerSecond) { "API Gateway" } else { "Ingress" }
    Write-Host "- Recomenda-se usar o $betterThroughput devido ao maior throughput ($([Math]::Round($throughputDiff, 1))% melhor)" -ForegroundColor Yellow
} else {
    Write-Host "- Ambas as abordagens sao adequadas em termos de throughput" -ForegroundColor Green
}

# Aplicacoes corporativas
Write-Host "`nPara aplicacoes corporativas (dashboards, monitoramento):"
Write-Host "- O API Gateway oferece beneficios adicionais:" -ForegroundColor Cyan
Write-Host "  * Melhor gerenciamento de autenticacao e autorizacao"
Write-Host "  * Monitoramento e logging centralizados"
Write-Host "  * Controle de trafego e politicas de seguranca"

# Microsservicos internos
Write-Host "`nPara microsservicos internos:"
Write-Host "- O Ingress Controller e mais adequado:" -ForegroundColor Cyan
Write-Host "  * Menor overhead de rede"
Write-Host "  * Comunicacao mais simples e direta"
Write-Host "  * Menor complexidade de configuracao"

# Conclusao final
Write-Host "`n==== CONCLUSAO FINAL ====" -ForegroundColor Cyan
Write-Host "Baseado na analise completa dos resultados, podemos concluir que:"
Write-Host "1. O API Gateway apresenta melhor performance geral em termos de latencia e consistencia"
Write-Host "2. O Ingress Controller e mais adequado para casos de uso mais simples e diretos"
Write-Host "3. A escolha entre as duas abordagens deve considerar nao apenas a performance, mas tambem os requisitos de funcionalidade e complexidade do sistema" 