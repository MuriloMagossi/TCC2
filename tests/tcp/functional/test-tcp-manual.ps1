# tests/tcp/functional/test-tcp-manual.ps1

Write-Host "==> Teste manual de TCP via Ingress Controller (porta 30901)..." -ForegroundColor Cyan

try {
    $client = New-Object System.Net.Sockets.TcpClient("localhost", 30901)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    $writer.WriteLine("teste-manual")
    $writer.Flush()
    Start-Sleep -Milliseconds 3000  # Aumenta ainda mais o tempo de espera

    # Tenta ler todas as linhas disponíveis
    $lines = @()
    while ($stream.DataAvailable) {
        $line = $reader.ReadLine()
        $lines += $line
        Write-Host "Linha recebida: '$line'" -ForegroundColor Yellow
    }
    if ($lines.Count -eq 0) {
        # Se não leu nada, tenta ler o buffer inteiro
        $buffer = $reader.ReadToEnd()
        Write-Host "Buffer recebido: '$buffer'" -ForegroundColor Cyan
        if ($buffer) {
            Write-Host "TCP respondeu, mas não foi o esperado: $buffer" -ForegroundColor DarkYellow
        } else {
            Write-Host "TCP FALHOU: resposta vazia" -ForegroundColor Red
        }
    } elseif ($lines -contains "teste-manual") {
        Write-Host "TCP OK (Ingress Controller): 'teste-manual'" -ForegroundColor Green
    } else {
        Write-Host "TCP respondeu, mas não foi o esperado: $($lines -join ', ')" -ForegroundColor DarkYellow
    }
    $writer.Close()
    $reader.Close()
    $client.Close()
} catch {
    Write-Host "TCP FALHOU: $($_.Exception.Message)" -ForegroundColor Red
} 