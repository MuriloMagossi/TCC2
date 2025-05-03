# Mapeamento de Portas dos Serviços e Ingress

| Protocolo | Serviço/Ingress         | Namespace      | Porta Externa | Porta Interna | Observação                |
|-----------|------------------------|---------------|---------------|---------------|---------------------------|
| HTTP      | http-echo (svc)        | http          | -             | 8081          | Backend HTTP              |
| HTTP      | Ingress Controller     | ingress-nginx | 8080          | 80            | Exposto no host           |
| HTTP      | nginx-apigw (svc)      | http          | NodePort      | 80            | API Gateway HTTP          |
| HTTPS     | https-echo (svc)       | https         | -             | 8081          | Backend HTTPS             |
| HTTPS     | Ingress Controller     | ingress-nginx | 8443          | 443           | Exposto no host           |
| HTTPS     | nginx-apigw (svc)      | https         | NodePort      | 443           | API Gateway HTTPS         |
| TCP       | tcp-echo (svc)         | tcp           | -             | 8081          | Backend TCP               |
| TCP       | Ingress Controller     | ingress-nginx | 30901         | 8081          | Exposto no host (NodePort)|
| TCP       | nginx-apigw-tcp (svc)  | tcp           | NodePort      | 8081          | API Gateway TCP           |
| GRPC      | grpc-echo (svc)        | grpc          | -             | 50051         | Backend gRPC              |
| GRPC      | Ingress Controller     | ingress-nginx | 31051         | 50051         | Exposto no host (NodePort)|
| GRPC      | nginx-apigw-grpc (svc) | grpc          | NodePort      | 50051         | API Gateway gRPC          |

> **Obs:** “Porta Externa” refere-se à porta exposta no host (localhost), “Porta Interna” à porta do serviço/pod.

- [X] Verificar o manifest do TCP e garantir que ele passe nos testes do scripts/test-all-protocols.ps1
- [ ] Após isso, partir para os testes de performance
- [ ] Corrigir os testes de performance dos protocolos HTTP e HTTPS que pararam de funcionar

30/04

 - [ ] Fazer análise de resultados automatizado, contendo graficos e BON (Big O Notation)
git 