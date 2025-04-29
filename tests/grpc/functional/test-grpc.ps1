# tests/grpc/functional/test-grpc.ps1

Write-Host "==> Teste funcional gRPC (grpcurl via Docker)" -ForegroundColor Cyan

# 1. Port-forward para o serviço grpc-echo na porta 9000
$pf = Start-Process -PassThru powershell -ArgumentList 'kubectl port-forward svc/grpc-echo 9000:9000'
Start-Sleep -Seconds 3

try {
    Write-Host "\n[1] Listando serviços gRPC disponíveis..." -ForegroundColor Yellow
    docker run --rm --network=host fullstorydev/grpcurl -plaintext localhost:9000 list

    Write-Host "\n[2] Chamando método Empty do grpcbin.GRPCBin..." -ForegroundColor Yellow
    docker run --rm --network=host fullstorydev/grpcurl -plaintext -d '{}' localhost:9000 grpcbin.GRPCBin/Empty
    Write-Host "\nTeste funcional gRPC OK!" -ForegroundColor Green
} catch {
    Write-Host "Teste funcional gRPC FALHOU: $($_.Exception.Message)" -ForegroundColor Red
}

if (Get-Process -Id $pf.Id -ErrorAction SilentlyContinue) {
    Stop-Process -Id $pf.Id
} 