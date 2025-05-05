# tests/https/functional/test-https.ps1

# Detectar NodePort do API Gateway HTTPS
$apigwPort = kubectl get svc nginx-apigw -n https -o jsonpath="{.spec.ports[0].nodePort}"
Write-Host "==> Testando HTTPS via API Gateway (porta $apigwPort)..." -ForegroundColor Cyan
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
    $result = Invoke-WebRequest -Uri "https://localhost:$apigwPort/" -UseBasicParsing
    Write-Host "HTTPS OK (API Gateway): $($result.Content)" -ForegroundColor Green
} catch {
    Write-Host "HTTPS FALHOU (API Gateway): $($_.Exception.Message)" -ForegroundColor Red
}

# Usar sempre a porta 8443 para o Ingress Controller HTTPS
$ingressPort = 8443
Write-Host "==> Testando HTTPS via Ingress Controller (porta $ingressPort)..." -ForegroundColor Cyan
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
    $result = Invoke-WebRequest -Uri "https://localhost:$ingressPort/" -Headers @{Host="https.localtest.me"} -UseBasicParsing
    Write-Host "HTTPS OK (Ingress Controller): $($result.Content)" -ForegroundColor Green
} catch {
    Write-Host "HTTPS FALHOU (Ingress Controller): $($_.Exception.Message)" -ForegroundColor Red
} 