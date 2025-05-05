# Script para coletar métricas Docker
$startTime = Get-Date
$endTime = $startTime.AddSeconds(30)

while ((Get-Date) -lt $endTime) {
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" | Add-Content -Path "tests/graphql/performance/results/docker-stats-graphql-apigw.csv"
    Start-Sleep -Seconds 1
}
