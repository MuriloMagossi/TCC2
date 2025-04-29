# scripts/test-all-protocols.ps1

# =========================
# 1. Aplicação dos manifests
# =========================
Write-Host "==> Aplicando HTTP..." -ForegroundColor Cyan
kubectl apply -n http -f manifests/http/app/
Write-Host "==> Aplicando Ingress Controller HTTP..." -ForegroundColor Cyan
kubectl apply -f manifests/http/nginx-ingress/
Write-Host "==> Aplicando API Gateway HTTP..." -ForegroundColor Cyan
kubectl apply -n http -f manifests/http/nginx-apigw/

Write-Host "==> Aplicando HTTPS..." -ForegroundColor Cyan
kubectl apply -f manifests/https/nginx-apigw/tls-secret.yaml
kubectl apply -n https -f manifests/https/app/
Write-Host "==> Aplicando API Gateway HTTPS..." -ForegroundColor Cyan
kubectl apply -n https -f manifests/https/nginx-apigw/
Write-Host "==> Aplicando Ingress Controller HTTPS..." -ForegroundColor Cyan
kubectl apply -f manifests/https/nginx-ingress/

Write-Host "==> Aplicando gRPC..." -ForegroundColor Cyan
kubectl apply -n grpc -f manifests/grpc/app/
Write-Host "==> Aplicando API Gateway gRPC..." -ForegroundColor Cyan
kubectl apply -n grpc -f manifests/grpc/nginx-apigw/

Write-Host "==> Aplicando TCP..." -ForegroundColor Cyan
kubectl apply -n tcp -f manifests/tcp/app/
Write-Host "==> Aplicando API Gateway TCP..." -ForegroundColor Cyan
kubectl apply -n tcp -f manifests/tcp/nginx-apigw/
Write-Host "==> Aplicando Ingress Controller TCP..." -ForegroundColor Cyan
kubectl apply -f manifests/tcp/nginx-ingress/

# =========================
# 2. Espera dos pods ficarem prontos
# =========================
Write-Host "==> Aguardando pods ficarem prontos..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod -l app=http-echo -n http --timeout=60s
kubectl wait --for=condition=Ready pod -l app=grpc-echo -n grpc --timeout=60s
kubectl wait --for=condition=Ready pod -l app=tcp-echo -n tcp --timeout=60s
kubectl wait --for=condition=Ready pod -l app=https-echo -n https --timeout=60s

# =========================
# 3. Testes HTTP
# =========================
Write-Host "\n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes HTTP" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan

# 3.1 HTTP via API Gateway
Write-Host "\n==> HTTP via API Gateway..." -ForegroundColor Cyan
try {
    $result = Invoke-WebRequest -Uri "http://localhost:30082/"
    Write-Host "HTTP OK (API Gateway): $($result.Content)" -ForegroundColor Green
} catch {
    Write-Host "HTTP FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}

# 3.2 HTTP via Ingress Controller
Write-Host "\n==> HTTP via Ingress Controller..." -ForegroundColor Cyan
try {
    $result = Invoke-WebRequest -Uri "http://localhost:8080/" -Headers @{Host="http.localtest.me"}
    Write-Host "HTTP OK (Ingress Controller): $($result.Content)" -ForegroundColor Green
} catch {
    Write-Host "HTTP FALHOU (Ingress Controller): $($_.Exception.Message)" -ForegroundColor Red
}

# =========================
# 4. Testes HTTPS
# =========================
Write-Host "\n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes HTTPS" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan

# 4.1 HTTPS via API Gateway
Write-Host "\n==> HTTPS via API Gateway..." -ForegroundColor Cyan
try {
    add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    $result = Invoke-WebRequest -Uri "https://localhost:30443/" -UseBasicParsing
    Write-Host "HTTPS OK (API Gateway): $($result.Content)" -ForegroundColor Green
} catch {
    Write-Host "HTTPS FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}

# 4.2 HTTPS via Ingress Controller
Write-Host "\n==> HTTPS via Ingress Controller..." -ForegroundColor Cyan
try {
    $result = Invoke-WebRequest -Uri "https://localhost:8443/" -Headers @{Host="https.localtest.me"} -UseBasicParsing
    Write-Host "HTTPS OK (Ingress Controller): $($result.Content)" -ForegroundColor Green
} catch {
    Write-Host "HTTPS FALHOU (Ingress Controller): $($_.Exception.Message)" -ForegroundColor Red
}

# =========================
# 5. Testes gRPC
# =========================
Write-Host "\n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes gRPC" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan

# 5.1 gRPC via serviço direto (port-forward)
Write-Host "\n==> gRPC via serviço direto (port-forward)..." -ForegroundColor Cyan
$pfGrpc = Start-Process -PassThru powershell -ArgumentList 'kubectl port-forward svc/grpc-echo 9000:9000 -n grpc'
Start-Sleep -Seconds 3
Write-Host "gRPC disponível em localhost:9000 (teste automatizado com grpcurl em Docker)" -ForegroundColor Yellow
try {
    docker run --rm --network=host fullstorydev/grpcurl -plaintext localhost:9000 list
    Write-Host "gRPC OK (serviço direto): grpcurl respondeu com lista de serviços" -ForegroundColor Green
} catch {
    Write-Host "gRPC FALHOU (serviço direto): $($_.Exception.Message)" -ForegroundColor Red
}
if (Get-Process -Id $pfGrpc.Id -ErrorAction SilentlyContinue) {
    Stop-Process -Id $pfGrpc.Id
}

# 5.2 gRPC via API Gateway (nginx-apigw)
Write-Host "\n==> gRPC via API Gateway (nginx-apigw)..." -ForegroundColor Cyan
$pfGrpcApiGw = Start-Process -PassThru powershell -ArgumentList 'kubectl port-forward svc/nginx-apigw-grpc 50551:50551 -n grpc'
Start-Sleep -Seconds 3
try {
    docker run --rm --network=host fullstorydev/grpcurl -plaintext localhost:50551 list
    Write-Host "gRPC OK (API Gateway): grpcurl respondeu com lista de serviços" -ForegroundColor Green
} catch {
    Write-Host "gRPC FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}
if (Get-Process -Id $pfGrpcApiGw.Id -ErrorAction SilentlyContinue) {
    Stop-Process -Id $pfGrpcApiGw.Id
}

# 5.3 gRPC via Ingress Controller
Write-Host "\n==> gRPC via Ingress Controller (NodePort 30900)..." -ForegroundColor Cyan
try {
    docker run --rm --network=host fullstorydev/grpcurl -plaintext localhost:30900 list
    Write-Host "gRPC OK (Ingress Controller): grpcurl respondeu com lista de serviços" -ForegroundColor Green
} catch {
    Write-Host "gRPC FALHOU (Ingress Controller): $($_.Exception.Message)" -ForegroundColor Red
}

# =========================
# 6. Testes TCP
# =========================
Write-Host "\n=====================" -ForegroundColor Cyan
Write-Host   "==> Testes TCP" -ForegroundColor Cyan
Write-Host   "=====================" -ForegroundColor Cyan

# 6.1 TCP via serviço direto (port-forward e conexão)
Write-Host "\n==> TCP via serviço direto (port-forward e conexão)..." -ForegroundColor Cyan
$pfTcp = Start-Process -PassThru powershell -ArgumentList 'kubectl port-forward svc/tcp-echo 9000:9000 -n tcp'
Start-Sleep -Seconds 3
try {
    $client = New-Object System.Net.Sockets.TcpClient("localhost", 9000)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    $writer.WriteLine("teste-automatizado")
    $writer.Flush()
    Start-Sleep -Milliseconds 500
    $response = $reader.ReadLine()
    Write-Host "TCP OK (serviço direto): $response" -ForegroundColor Green
    $writer.Close()
    $reader.Close()
    $client.Close()
} catch {
    Write-Host "TCP FALHOU (serviço direto): $($_.Exception.Message)" -ForegroundColor Red
}
if (Get-Process -Id $pfTcp.Id -ErrorAction SilentlyContinue) {
    Stop-Process -Id $pfTcp.Id
}

# 6.2 TCP via API Gateway (nginx-apigw)
Write-Host "\n==> TCP via API Gateway (nginx-apigw)..." -ForegroundColor Cyan
$pfTcpApiGw = Start-Process -PassThru powershell -ArgumentList 'kubectl port-forward svc/nginx-apigw-tcp 50552:50552 -n tcp'
Start-Sleep -Seconds 3
try {
    $client = New-Object System.Net.Sockets.TcpClient("localhost", 50552)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    $writer.WriteLine("teste-automatizado")
    $writer.Flush()
    Start-Sleep -Milliseconds 500
    $response = $reader.ReadLine()
    Write-Host "TCP OK (API Gateway): $response" -ForegroundColor Green
    $writer.Close()
    $reader.Close()
    $client.Close()
} catch {
    Write-Host "TCP FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}
if (Get-Process -Id $pfTcpApiGw.Id -ErrorAction SilentlyContinue) {
    Stop-Process -Id $pfTcpApiGw.Id
}

# 6.3 TCP via Ingress Controller
Write-Host "\n==> TCP via Ingress Controller (NodePort 30901)..." -ForegroundColor Cyan
try {
    $client = New-Object System.Net.Sockets.TcpClient("localhost", 30901)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    $writer.WriteLine("teste-automatizado")
    $writer.Flush()
    Start-Sleep -Milliseconds 500
    $response = $reader.ReadLine()
    Write-Host "TCP OK (Ingress Controller): $response" -ForegroundColor Green
    $writer.Close()
    $reader.Close()
    $client.Close()
} catch {
    Write-Host "TCP FALHOU (Ingress Controller): $($_.Exception.Message)" -ForegroundColor Red
}

# =========================
# 7. Encerrando port-forwards abertos
# =========================
Write-Host "\n==> Encerrando port-forwards abertos..." -ForegroundColor Cyan

# Fechar port-forward gRPC direto
if ($pfGrpc -and (Get-Process -Id $pfGrpc.Id -ErrorAction SilentlyContinue)) {
    Stop-Process -Id $pfGrpc.Id -Force
    Write-Host "Port-forward gRPC direto encerrado." -ForegroundColor Yellow
}

# Fechar port-forward gRPC API Gateway
if ($pfGrpcApiGw -and (Get-Process -Id $pfGrpcApiGw.Id -ErrorAction SilentlyContinue)) {
    Stop-Process -Id $pfGrpcApiGw.Id -Force
    Write-Host "Port-forward gRPC API Gateway encerrado." -ForegroundColor Yellow
}

# Fechar port-forward TCP direto
if ($pfTcp -and (Get-Process -Id $pfTcp.Id -ErrorAction SilentlyContinue)) {
    Stop-Process -Id $pfTcp.Id -Force
    Write-Host "Port-forward TCP direto encerrado." -ForegroundColor Yellow
}

# Fechar port-forward TCP API Gateway
if ($pfTcpApiGw -and (Get-Process -Id $pfTcpApiGw.Id -ErrorAction SilentlyContinue)) {
    Stop-Process -Id $pfTcpApiGw.Id -Force
    Write-Host "Port-forward TCP API Gateway encerrado." -ForegroundColor Yellow
}