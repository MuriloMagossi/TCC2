# tests/websocket/performance/run-websocket-benchmark-apigw.ps1

# Parâmetros do teste
$connections = 100
$messageCount = 200
$duration = 30 # segundos

# Diretório e arquivo para salvar métricas do Docker
$resultsDir = Join-Path $PSScriptRoot "results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}
$dockerStatsFile = Join-Path $resultsDir "docker-stats-websocket-apigw.csv"
$dockerStatsHeader = "Name,CPU %,Mem Usage / Limit,Net I/O,Block I/O"
Set-Content -Path $dockerStatsFile -Value $dockerStatsHeader

# Iniciar port-forward para API Gateway WebSocket
Write-Host "==> Iniciando port-forward para WebSocket API Gateway..." -ForegroundColor Cyan
$apigwPort = 9801
$portForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward svc/nginx-apigw-ws $($apigwPort):80 -n websocket" -PassThru -NoNewWindow
Start-Sleep -Seconds 3 # Aguardar conexão ser estabelecida

# Verificar se Node.js está instalado (necessário para teste WebSocket adequado)
$nodeInstalled = Get-Command "node" -ErrorAction SilentlyContinue
if (-not $nodeInstalled) {
    Write-Host "[AVISO] Node.js não está instalado. Usando teste básico com conexões TCP." -ForegroundColor Yellow
    
    # Teste básico usando TCP nativo
    Write-Host "==> Executando teste básico de conexão TCP para WebSocket API Gateway..." -ForegroundColor Cyan
    
    $successful = 0
    $failed = 0
    $startTime = Get-Date
    $connectionTimes = @()
    
    for ($i = 1; $i -le $connections; $i++) {
        Write-Host "Conexão $i de $connections..." -ForegroundColor Gray
        
        # Iniciar coleta de estatísticas Docker durante o teste
        if ($i % 10 -eq 0) {
            docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" | Add-Content -Path $dockerStatsFile
        }
        
        $connectionStart = Get-Date
        $client = New-Object System.Net.Sockets.TcpClient
        $task = $client.ConnectAsync("localhost", $apigwPort)
        
        if ($task.Wait(2000) -and $client.Connected) {
            $connectionEnd = Get-Date
            $connectionTime = ($connectionEnd - $connectionStart).TotalMilliseconds
            $connectionTimes += $connectionTime
            
            $successful++
            Write-Host "  Conectado em $([Math]::Round($connectionTime, 0)) ms" -ForegroundColor Green
            $client.Close()
        } else {
            $failed++
            Write-Host "  Falha" -ForegroundColor Red
            if ($client.Connected) { $client.Close() }
        }
        
        # Pequena pausa
        Start-Sleep -Milliseconds 100
    }
    
    $endTime = Get-Date
    $durationSecs = ($endTime - $startTime).TotalSeconds
    $successRate = ($successful / $connections) * 100
    $connectionsPerSecond = $connections / $durationSecs
    
    # Calcular estatísticas
    $connectionTimes = $connectionTimes | Sort-Object
    $avgConnectionTime = ($connectionTimes | Measure-Object -Average).Average
    $minConnectionTime = ($connectionTimes | Measure-Object -Minimum).Minimum
    $maxConnectionTime = ($connectionTimes | Measure-Object -Maximum).Maximum
    
    # Percentis
    $totalTimesCount = $connectionTimes.Count
    $p10Index = [Math]::Floor($totalTimesCount * 0.10)
    $p25Index = [Math]::Floor($totalTimesCount * 0.25)
    $p50Index = [Math]::Floor($totalTimesCount * 0.50)
    $p75Index = [Math]::Floor($totalTimesCount * 0.75)
    $p90Index = [Math]::Floor($totalTimesCount * 0.90)
    $p95Index = [Math]::Floor($totalTimesCount * 0.95)
    $p99Index = [Math]::Floor($totalTimesCount * 0.99)
    
    $p10Time = if ($p10Index -lt $connectionTimes.Count) { $connectionTimes[$p10Index] } else { 0 }
    $p25Time = if ($p25Index -lt $connectionTimes.Count) { $connectionTimes[$p25Index] } else { 0 }
    $p50Time = if ($p50Index -lt $connectionTimes.Count) { $connectionTimes[$p50Index] } else { 0 }
    $p75Time = if ($p75Index -lt $connectionTimes.Count) { $connectionTimes[$p75Index] } else { 0 }
    $p90Time = if ($p90Index -lt $connectionTimes.Count) { $connectionTimes[$p90Index] } else { 0 }
    $p95Time = if ($p95Index -lt $connectionTimes.Count) { $connectionTimes[$p95Index] } else { 0 }
    $p99Time = if ($p99Index -lt $connectionTimes.Count) { $connectionTimes[$p99Index] } else { 0 }
    
    # Criar histograma
    $histogramBuckets = 10
    $minTime = $minConnectionTime
    $maxTime = $maxConnectionTime
    $bucketSize = ($maxTime - $minTime) / $histogramBuckets
    $buckets = @(0) * $histogramBuckets
    
    foreach ($time in $connectionTimes) {
        $bucketIndex = [Math]::Min([Math]::Floor(($time - $minTime) / $bucketSize), $histogramBuckets - 1)
        $buckets[$bucketIndex]++
    }
    
    # Encontrar o bucket com mais elementos para normalização
    $maxBucketCount = ($buckets | Measure-Object -Maximum).Maximum
    
    # Salvar resultados detalhados
    $histogramStr = ""
    for ($i = 0; $i -lt $histogramBuckets; $i++) {
        $bucketStart = $minTime + ($i * $bucketSize)
        $bucketEnd = $minTime + (($i + 1) * $bucketSize)
        $barLength = if ($maxBucketCount -gt 0) { [Math]::Round(($buckets[$i] / $maxBucketCount) * 40) } else { 0 }
        $bar = if ($barLength -gt 0) { "#" * $barLength } else { "" }
        $histogramStr += "  $([Math]::Round($bucketStart, 1)) - $([Math]::Round($bucketEnd, 1)) [$($buckets[$i])] `t|$bar`n"
    }
    
    # Calcular desvio padrão manualmente
    $avgTime = ($connectionTimes | Measure-Object -Average).Average
    $sumSquaredDiff = 0
    foreach ($time in $connectionTimes) {
        $diff = $time - $avgTime
        $sumSquaredDiff += $diff * $diff
    }
    $stdDev = [Math]::Sqrt($sumSquaredDiff / ($connectionTimes.Count - 1))
    
    $resultStr = @"
==== RESULTADOS DO TESTE WEBSOCKET API GATEWAY ====

Sumário:
  Duração total:       $([Math]::Round($durationSecs, 4)) segundos
  Mais lento:          $([Math]::Round($maxConnectionTime, 4)) ms
  Mais rápido:         $([Math]::Round($minConnectionTime, 4)) ms
  Média:               $([Math]::Round($avgConnectionTime, 4)) ms
  Conexões/segundo:    $([Math]::Round($connectionsPerSecond, 4))
  
  Tentativas:          $connections
  Bem-sucedidas:       $successful
  Taxa de sucesso:     $([Math]::Round($successRate, 2))%

Histograma de tempo de conexão (ms):
$histogramStr

Distribuição de latência:
  10% em $([Math]::Round($p10Time, 4)) ms
  25% em $([Math]::Round($p25Time, 4)) ms
  50% em $([Math]::Round($p50Time, 4)) ms
  75% em $([Math]::Round($p75Time, 4)) ms
  90% em $([Math]::Round($p90Time, 4)) ms
  95% em $([Math]::Round($p95Time, 4)) ms
  99% em $([Math]::Round($p99Time, 4)) ms

Detalhes:
  Tempo médio de conexão: $([Math]::Round($avgConnectionTime, 2)) ms
  Desvio padrão: $([Math]::Round($stdDev, 2)) ms

"@
    
    $resultStr | Out-File -FilePath $(Join-Path $resultsDir 'ws-benchmark-apigw-result.txt') -Encoding utf8
    $resultStr | ForEach-Object { Write-Host $_ }
    
} else {
    # Usar teste Node.js WebSocket adequado
    Write-Host "==> Executando teste WebSocket nativo com Node.js para API Gateway..." -ForegroundColor Cyan

    # Script para testar WebSocket com Node.js
    $wsTestScript = @"
const WebSocket = require('ws');
const url = 'ws://localhost:$apigwPort';

// Configurações
const CONNECTIONS = $connections;
const MESSAGES_PER_CONNECTION = $messageCount;
const CONCURRENT_CLIENTS = 10;
const MAX_DURATION_MS = $($duration * 1000);

// Arrays para métricas
let latencies = [];
let connectionTimes = [];
let messageTimes = [];
let messagesSent = 0;
let messagesReceived = 0;
let connectionsAttempted = 0;
let connectionsSuccessful = 0;
let connectionsFailed = 0;
let errors = 0;

const startTime = Date.now();
let endTime;

// Criar histograma
function createHistogram(data, buckets = 10) {
    if (data.length === 0) return { buckets: [], min: 0, max: 0, bucketSize: 0, counts: [] };
    
    const min = Math.min(...data);
    const max = Math.max(...data);
    const bucketSize = (max - min) / buckets;
    const counts = Array(buckets).fill(0);
    
    data.forEach(value => {
        const bucketIndex = Math.min(Math.floor((value - min) / bucketSize), buckets - 1);
        counts[bucketIndex]++;
    });
    
    return { min, max, bucketSize, counts, buckets };
}

// Calcular percentis
function calculatePercentile(sortedData, percentile) {
    if (sortedData.length === 0) return 0;
    const index = Math.floor(sortedData.length * percentile / 100);
    return sortedData[Math.min(index, sortedData.length - 1)];
}

function createConnection(id) {
    if (Date.now() - startTime > MAX_DURATION_MS) {
        if (!endTime) endTest();
        return;
    }
    
    connectionsAttempted++;
    const connectionStartTime = Date.now();
    
    const ws = new WebSocket(url);
    const connectionMessages = [];
    
    ws.on('open', () => {
        const connectionEstablishTime = Date.now() - connectionStartTime;
        connectionTimes.push(connectionEstablishTime);
        connectionsSuccessful++;
        
        for (let i = 0; i < MESSAGES_PER_CONNECTION; i++) {
            const message = {
                id: \`msg-\${i}-\${Date.now()}-\${id}\`,
                timestamp: Date.now(),
                data: \`Test message \${i}\`
            };
            const msgStr = JSON.stringify(message);
            connectionMessages.push(message);
            ws.send(msgStr);
            messagesSent++;
        }
    });
    
    ws.on('message', (data) => {
        try {
            const response = JSON.parse(data.toString());
            const originalMsg = connectionMessages.find(m => m.id === response.id);
            if (originalMsg) {
                const msgLatency = Date.now() - originalMsg.timestamp;
                latencies.push(msgLatency);
                messageTimes.push(msgLatency);
            }
            
            messagesReceived++;
            
            if (messagesReceived % MESSAGES_PER_CONNECTION === 0) {
                ws.close();
                
                // Iniciar nova conexão para manter concorrência
                if (connectionsAttempted < CONNECTIONS && Date.now() - startTime < MAX_DURATION_MS) {
                    createConnection(connectionsAttempted + 1);
                }
            }
        } catch (e) {
            errors++;
        }
    });
    
    ws.on('close', () => {
        // Verificar se teste terminou
        if (connectionsAttempted >= CONNECTIONS || messagesReceived >= CONNECTIONS * MESSAGES_PER_CONNECTION) {
            if (!endTime) endTest();
        }
    });
    
    ws.on('error', (err) => {
        errors++;
        connectionsFailed++;
    });
    
    // Timeout para conexão
    setTimeout(() => {
        if (ws.readyState !== WebSocket.OPEN) {
            ws.terminate();
            connectionsFailed++;
            
            // Iniciar nova conexão para manter concorrência
            if (connectionsAttempted < CONNECTIONS && Date.now() - startTime < MAX_DURATION_MS) {
                createConnection(connectionsAttempted + 1);
            }
        }
    }, 5000);
}

function endTest() {
    endTime = Date.now();
    const durationSec = (endTime - startTime) / 1000;
    
    // Ordenar dados para percentis
    connectionTimes.sort((a, b) => a - b);
    messageTimes.sort((a, b) => a - b);
    
    // Calcular estatísticas de conexão
    const connAvg = connectionTimes.reduce((sum, time) => sum + time, 0) / connectionTimes.length || 0;
    const connHistogram = createHistogram(connectionTimes);
    
    // Calcular estatísticas de mensagens
    const msgAvg = messageTimes.reduce((sum, time) => sum + time, 0) / messageTimes.length || 0;
    const msgHistogram = createHistogram(messageTimes);
    
    // Criar string do histograma de conexão
    let connHistogramStr = '';
    const maxConnCount = Math.max(...connHistogram.counts);
    for (let i = 0; i < connHistogram.buckets; i++) {
        const bucketStart = connHistogram.min + (i * connHistogram.bucketSize);
        const bucketEnd = connHistogram.min + ((i + 1) * connHistogram.bucketSize);
        const barLength = Math.round((connHistogram.counts[i] / maxConnCount) * 40) || 0;
        const bar = ''.padStart(barLength, '■');
        connHistogramStr += \`  \${bucketStart.toFixed(1)} - \${bucketEnd.toFixed(1)} [\${connHistogram.counts[i]}] \\t|\${bar}\\n\`;
    }
    
    // Criar string do histograma de mensagens
    let msgHistogramStr = '';
    const maxMsgCount = Math.max(...msgHistogram.counts);
    for (let i = 0; i < msgHistogram.buckets; i++) {
        const bucketStart = msgHistogram.min + (i * msgHistogram.bucketSize);
        const bucketEnd = msgHistogram.min + ((i + 1) * msgHistogram.bucketSize);
        const barLength = Math.round((msgHistogram.counts[i] / maxMsgCount) * 40) || 0;
        const bar = ''.padStart(barLength, '■');
        msgHistogramStr += \`  \${bucketStart.toFixed(1)} - \${bucketEnd.toFixed(1)} [\${msgHistogram.counts[i]}] \\t|\${bar}\\n\`;
    }
    
    // Resultados
    console.log(\`==== RESULTADOS DO TESTE WEBSOCKET API GATEWAY ====

Sumário:
  Duração total:        \${durationSec.toFixed(4)} segundos
  Taxa de mensagens:    \${(messagesReceived / durationSec).toFixed(4)} msgs/seg
  Taxa de conexões:     \${(connectionsSuccessful / durationSec).toFixed(4)} conn/seg
  
  Conexões tentadas:    \${connectionsAttempted}
  Conexões sucesso:     \${connectionsSuccessful}
  Conexões falhas:      \${connectionsFailed}
  Taxa de sucesso:      \${((connectionsSuccessful / connectionsAttempted) * 100).toFixed(2)}%
  
  Mensagens enviadas:   \${messagesSent}
  Mensagens recebidas:  \${messagesReceived}
  Taxa de entrega:      \${((messagesReceived / messagesSent) * 100).toFixed(2)}%
  Erros:                \${errors}
  
  Latência média (conn): \${connAvg.toFixed(2)} ms
  Latência média (msg):  \${msgAvg.toFixed(2)} ms
  
Histograma de tempo de conexão (ms):
\${connHistogramStr}

Distribuição da latência de conexão:
  10% em \${calculatePercentile(connectionTimes, 10).toFixed(2)} ms
  25% em \${calculatePercentile(connectionTimes, 25).toFixed(2)} ms
  50% em \${calculatePercentile(connectionTimes, 50).toFixed(2)} ms
  75% em \${calculatePercentile(connectionTimes, 75).toFixed(2)} ms
  90% em \${calculatePercentile(connectionTimes, 90).toFixed(2)} ms
  95% em \${calculatePercentile(connectionTimes, 95).toFixed(2)} ms
  99% em \${calculatePercentile(connectionTimes, 99).toFixed(2)} ms

Histograma de tempo de mensagem (ms):
\${msgHistogramStr}

Distribuição da latência de mensagem:
  10% em \${calculatePercentile(messageTimes, 10).toFixed(2)} ms
  25% em \${calculatePercentile(messageTimes, 25).toFixed(2)} ms
  50% em \${calculatePercentile(messageTimes, 50).toFixed(2)} ms
  75% em \${calculatePercentile(messageTimes, 75).toFixed(2)} ms
  90% em \${calculatePercentile(messageTimes, 90).toFixed(2)} ms
  95% em \${calculatePercentile(messageTimes, 95).toFixed(2)} ms
  99% em \${calculatePercentile(messageTimes, 99).toFixed(2)} ms
\`);
    
    process.exit(0);
}

// Iniciar teste com clientes concorrentes
console.log(\`Iniciando teste com \${CONCURRENT_CLIENTS} clientes concorrentes (\${CONNECTIONS} conexões totais)...\`);
for (let i = 0; i < Math.min(CONCURRENT_CLIENTS, CONNECTIONS); i++) {
    createConnection(i + 1);
}

// Garantir que o teste termine após o tempo máximo
setTimeout(() => {
    if (!endTime) endTest();
}, MAX_DURATION_MS);
"@

    # Verificar se temos dependências instaladas
    $tempDir = Join-Path $resultsDir "temp"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }
    
    # Salvar o script temporário
    $scriptPath = Join-Path $tempDir "ws-benchmark-apigw.js"
    Set-Content -Path $scriptPath -Value $wsTestScript
    
    # Verificar e instalar a biblioteca ws se necessário
    if (-not (Test-Path $(Join-Path $tempDir "node_modules\ws"))) {
        Write-Host "Instalando dependências necessárias para o teste WebSocket..." -ForegroundColor Yellow
        Push-Location $tempDir
        npm init -y | Out-Null
        npm install ws | Out-Null
        Pop-Location
    }
    
    # Iniciar coleta de métricas Docker enquanto o teste executa
    Write-Host "==> Iniciando coleta de métricas Docker durante o teste..." -ForegroundColor Cyan
    $statsCollectionScript = @"
# Script para coletar métricas Docker
`$startTime = Get-Date
`$endTime = `$startTime.AddSeconds($duration)

while ((Get-Date) -lt `$endTime) {
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" | Add-Content -Path "$dockerStatsFile"
    Start-Sleep -Seconds 1
}
"@

    $statsScriptPath = Join-Path $tempDir "collect-docker-stats.ps1"
    Set-Content -Path $statsScriptPath -Value $statsCollectionScript
    $statsProcess = Start-Process -FilePath "powershell" -ArgumentList "-File $statsScriptPath" -NoNewWindow -PassThru
    
    # Executar o teste
    Push-Location $tempDir
    node $scriptPath | Tee-Object -FilePath $(Join-Path $resultsDir 'ws-benchmark-apigw-result.txt')
    Pop-Location
    
    # Aguardar finalização da coleta de métricas
    if ($statsProcess -and -not $statsProcess.HasExited) {
        Write-Host "Aguardando conclusão da coleta de métricas Docker..." -ForegroundColor Gray
        $statsProcess.WaitForExit()
    }
}

# Finalizar port-forward
if ($portForwardProcess -and -not $portForwardProcess.HasExited) {
    Stop-Process -Id $portForwardProcess.Id -Force -ErrorAction SilentlyContinue
    Write-Host "Port-forward finalizado" -ForegroundColor Gray
}

# Limpar arquivos temporários
$tempDir = Join-Path $resultsDir "temp"
if (Test-Path $tempDir) {
    Write-Host "Limpando arquivos temporários..." -ForegroundColor Gray
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "==> Benchmark WebSocket API Gateway concluído!" -ForegroundColor Green
Write-Host "Resultados salvos em $(Join-Path $resultsDir 'ws-benchmark-apigw-result.txt')" 