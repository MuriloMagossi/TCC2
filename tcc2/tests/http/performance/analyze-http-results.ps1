# tests/http/performance/analyze-http-results.ps1

# Configuracao de codificacao para caracteres especiais
$OutputEncoding = [System.Text.Encoding]::GetEncoding('Windows-1252')
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding('Windows-1252')
[Console]::InputEncoding = [System.Text.Encoding]::GetEncoding('Windows-1252')

# Diretorio de resultados
$resultsDir = "tests/http/performance/results"
$apigwResults = "$resultsDir/hey-http-apigw-result.txt"
$ingressResults = "$resultsDir/hey-http-ingress-result.txt"
$apigwStatsFile = "$resultsDir/docker-stats-http-apigw.csv"
$ingressStatsFile = "$resultsDir/docker-stats-http-ingress.csv"

function Get-HeyBenchmarkData {
    param (
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "Arquivo nao encontrado: $FilePath"
        return $null
    }
    
    $content = Get-Content -Path $FilePath -Raw
    
    # Extrair dados usando regex
    $data = @{}
    
    # Duracao total
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
    
    # Requisicoes por segundo
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
    
    # Distribuicao de latencia
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

function Get-DockerStats {
    param (
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "Arquivo de estatisticas nao encontrado: $FilePath"
        return $null
    }
    
    $stats = Import-Csv $FilePath
    
    # Calcular medias
    $cpuStats = $stats.'CPU %' | ForEach-Object { [double]($_ -replace '%', '') }
    $memStats = $stats.'Mem Usage / Limit' | ForEach-Object {
        $usage = ($_ -split ' / ')[0]
        if ($usage -match '(\d+\.?\d*)(\w+)') {
            $value = [double]$matches[1]
            $unit = $matches[2]
            switch ($unit) {
                'KiB' { $value = $value / (1024 * 1024) }
                'MiB' { $value = $value / 1024 }
                'GiB' { $value = $value }
            }
            $value
        } else { 0 }
    }
    
    return @{
        AverageCPU = ($cpuStats | Measure-Object -Average).Average
        MaxCPU = ($cpuStats | Measure-Object -Maximum).Maximum
        AverageMemoryGiB = ($memStats | Measure-Object -Average).Average
        MaxMemoryGiB = ($memStats | Measure-Object -Maximum).Maximum
    }
}

function Format-ComparisonTable {
    param (
        [string]$Title,
        [PSCustomObject]$Data1,
        [string]$Label1,
        [PSCustomObject]$Data2,
        [string]$Label2
    )
    
    # Verificar se ha dados
    if ($null -eq $Data1 -or $null -eq $Data2) {
        Write-Host "Nao foi possivel obter dados suficientes para analise. Certifique-se de que os arquivos de resultados existem." -ForegroundColor Red
        return
    }
    
    # Metricas comuns para testes com hey
    $metrics = @(
        @{Name = "Duracao total (s)"; Data1 = $Data1.Duration; Data2 = $Data2.Duration; Format = "F2"; HigherIsBetter = $false}
        @{Name = "Requisicoes/segundo"; Data1 = $Data1.RequestsPerSecond; Data2 = $Data2.RequestsPerSecond; Format = "F2"; HigherIsBetter = $true}
        @{Name = "Tempo medio (s)"; Data1 = $Data1.Average; Data2 = $Data2.Average; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Mais rapido (s)"; Data1 = $Data1.Fastest; Data2 = $Data2.Fastest; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Mais lento (s)"; Data1 = $Data1.Slowest; Data2 = $Data2.Slowest; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Latencia P50 (s)"; Data1 = $Data1.Latency50; Data2 = $Data2.Latency50; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Latencia P90 (s)"; Data1 = $Data1.Latency90; Data2 = $Data2.Latency90; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Latencia P95 (s)"; Data1 = $Data1.Latency95; Data2 = $Data2.Latency95; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Latencia P99 (s)"; Data1 = $Data1.Latency99; Data2 = $Data2.Latency99; Format = "F4"; HigherIsBetter = $false}
        @{Name = "Total de respostas"; Data1 = $Data1.TotalResponses; Data2 = $Data2.TotalResponses; Format = "N0"; HigherIsBetter = $true}
        @{Name = "Tamanho/resposta (bytes)"; Data1 = $Data1.SizePerRequest; Data2 = $Data2.SizePerRequest; Format = "N0"; HigherIsBetter = $false}
    )
    
    # Cabecalho de tabela
    $headerFormat = "{0,-25} | {1,-15} | {2,-15} | {3,-12} | {4}"
    $separatorLine = "-" * 90
    
    Write-Host "$Title" -ForegroundColor Cyan
    Write-Host $separatorLine
    $header = $headerFormat -f "Metrica", $Label1, $Label2, "Diferenca", "Melhor"
    Write-Host $header
    Write-Host $separatorLine
    
    # Linhas da tabela
    foreach ($metric in $metrics) {
        # Calcular diferenca e determinar o melhor
        $diff = $metric.Data1 - $metric.Data2
        $percentDiff = if (($null -ne $metric.Data2) -and ($metric.Data2 -ne 0)) { 
            ($diff / $metric.Data2) * 100 
        } else { 
            0 
        }
        
        # Determinar qual abordagem e melhor com base no sentido da metrica
        $betterApproach = ""
        if (($null -ne $diff) -and ([Math]::Abs([double]$diff) -gt 0.01)) {
            if ($metric.HigherIsBetter) {
                $betterApproach = if ($diff -gt 0) { $Label1 } else { $Label2 }
            } else {
                $betterApproach = if ($diff -lt 0) { $Label1 } else { $Label2 }
            }
        }
        
        # Determinar cor com base em qual e melhor
        $color = if ($betterApproach -eq $Label1) { "Yellow" } elseif ($betterApproach -eq $Label2) { "Green" } else { "Gray" }
        
        # Formatar valores
        $data1ValueStr = if ($null -ne $metric.Data1) { "{0:$($metric.Format)}" -f $metric.Data1 } else { "N/A" }
        $data2ValueStr = if ($null -ne $metric.Data2) { "{0:$($metric.Format)}" -f $metric.Data2 } else { "N/A" }
        
        # Formatar diferenca
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

# Extrair dados dos testes
$apigwData = Get-HeyBenchmarkData -FilePath $apigwResults
$ingressData = Get-HeyBenchmarkData -FilePath $ingressResults

# Extrair estatisticas do Docker
$apigwStats = Get-DockerStats -FilePath $apigwStatsFile
$ingressStats = Get-DockerStats -FilePath $ingressStatsFile

# Exibir resultados comparativos
Write-Host "`n==== ANALISE COMPARATIVA: API GATEWAY vs INGRESS CONTROLLER (HTTP) ====" -ForegroundColor Cyan

# Comparacao de performance
Format-ComparisonTable -Title "`n=== Comparacao de Performance ===" -Data1 $apigwData -Label1 "API Gateway" -Data2 $ingressData -Label2 "Ingress"

# Exibir estatisticas de recursos
Write-Host "`n=== Estatisticas de Recursos ===" -ForegroundColor Cyan
Write-Host "API Gateway:" -ForegroundColor Yellow
Write-Host "- CPU Media: $([Math]::Round($apigwStats.AverageCPU, 2))%" -ForegroundColor Yellow
Write-Host "- CPU Maxima: $([Math]::Round($apigwStats.MaxCPU, 2))%" -ForegroundColor Yellow
Write-Host "- Memoria Media: $([Math]::Round($apigwStats.AverageMemoryGiB, 2)) GiB" -ForegroundColor Yellow
Write-Host "- Memoria Maxima: $([Math]::Round($apigwStats.MaxMemoryGiB, 2)) GiB" -ForegroundColor Yellow

Write-Host "`nIngress Controller:" -ForegroundColor Green
Write-Host "- CPU Media: $([Math]::Round($ingressStats.AverageCPU, 2))%" -ForegroundColor Green
Write-Host "- CPU Maxima: $([Math]::Round($ingressStats.MaxCPU, 2))%" -ForegroundColor Green
Write-Host "- Memoria Media: $([Math]::Round($ingressStats.AverageMemoryGiB, 2)) GiB" -ForegroundColor Green
Write-Host "- Memoria Maxima: $([Math]::Round($ingressStats.MaxMemoryGiB, 2)) GiB" -ForegroundColor Green

# Analise dos codigos de status
Write-Host "`n=== Distribuicao de Codigos de Status ===" -ForegroundColor Cyan
Write-Host "API Gateway:" -ForegroundColor Yellow
foreach ($code in $apigwData.StatusCodes.Keys | Sort-Object) {
    Write-Host "- Status $code : $($apigwData.StatusCodes[$code]) respostas" -ForegroundColor Yellow
}

Write-Host "`nIngress Controller:" -ForegroundColor Green
foreach ($code in $ingressData.StatusCodes.Keys | Sort-Object) {
    Write-Host "- Status $code : $($ingressData.StatusCodes[$code]) respostas" -ForegroundColor Green
}

# Conclusoes
Write-Host "`n==== CONCLUSOES ====" -ForegroundColor Cyan

# Calcular diferencas percentuais para metricas chave
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

# Conclusao sobre latencia
if (($null -ne $latencyDiffPercent) -and ([Math]::Abs([double]$latencyDiffPercent)) -lt 5) {
    Write-Host "- Latencia: As duas abordagens apresentam latencia similar (diferenca < 5%)" -ForegroundColor Cyan
} elseif (($null -ne $latencyDiffPercent) -and ($latencyDiffPercent -gt 0)) {
    Write-Host "- Latencia: O Ingress Controller apresenta latencia $([Math]::Abs([double]$latencyDiffPercent).ToString("F1"))% menor que o API Gateway" -ForegroundColor Yellow
} else {
    Write-Host "- Latencia: O API Gateway apresenta latencia $([Math]::Abs([double]$latencyDiffPercent).ToString("F1"))% menor que o Ingress Controller" -ForegroundColor Yellow
}

# Conclusao sobre throughput
if (($null -ne $throughputDiffPercent) -and ([Math]::Abs([double]$throughputDiffPercent)) -lt 5) {
    Write-Host "- Throughput: As duas abordagens apresentam taxa de requisicoes similar (diferenca < 5%)" -ForegroundColor Cyan
} elseif (($null -ne $throughputDiffPercent) -and ($throughputDiffPercent -gt 0)) {
    Write-Host "- Throughput: O API Gateway processa $([Math]::Abs([double]$throughputDiffPercent).ToString("F1"))% mais requisicoes por segundo" -ForegroundColor Green
} else {
    Write-Host "- Throughput: O Ingress Controller processa $([Math]::Abs([double]$throughputDiffPercent).ToString("F1"))% mais requisicoes por segundo" -ForegroundColor Green
}

# Conclusao sobre recursos
$cpuDiffPercent = (($apigwStats.AverageCPU - $ingressStats.AverageCPU) / $ingressStats.AverageCPU) * 100
Write-Host "- Recursos: O API Gateway utiliza $([Math]::Abs($cpuDiffPercent).ToString("F1"))% $(if ($cpuDiffPercent -gt 0) { 'mais' } else { 'menos' }) CPU em media" -ForegroundColor Cyan

# Conclusao final
Write-Host "`n==== RECOMENDACOES ====" -ForegroundColor Cyan
Write-Host "- Para aplicacoes com alto volume de requisicoes: Prefira o metodo com maior throughput."
Write-Host "- Para aplicacoes sensiveis a latencia: Considere o metodo com menor latencia media e P95/P99."
Write-Host "- Para ambientes com recursos limitados: Avalie o consumo de CPU e memoria de cada abordagem."
Write-Host "- Para aplicacoes corporativas: Considere os recursos adicionais oferecidos pelo API Gateway." 