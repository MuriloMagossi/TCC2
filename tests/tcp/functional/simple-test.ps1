# Simples teste TCP
try {
    $client = New-Object System.Net.Sockets.TcpClient("localhost", 9090)
    if ($client.Connected) {
        Write-Host "Conectado com sucesso!" -ForegroundColor Green
        
        $stream = $client.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $reader = New-Object System.IO.StreamReader($stream)
        
        # Envia mensagem de teste
        $writer.WriteLine("teste-tcp-simples")
        $writer.Flush()
        
        # Aguarda resposta
        Start-Sleep -s 2
        
        if ($stream.DataAvailable) {
            $response = $reader.ReadLine()
            Write-Host "Resposta recebida: $response" -ForegroundColor Green
        } else {
            Write-Host "Nenhuma resposta recebida após 2 segundos" -ForegroundColor Red
        }
        
        $writer.Close()
        $reader.Close()
        $client.Close()
    } else {
        Write-Host "Não foi possível conectar" -ForegroundColor Red
    }
} catch {
    Write-Host "Erro: $($_.Exception.Message)" -ForegroundColor Red
} 