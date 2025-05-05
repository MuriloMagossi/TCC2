#!/usr/bin/env python3

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import json

def load_test_results(results_dir):
    """Carrega os resultados dos testes de cada protocolo e gateway."""
    results = {}
    for file in Path(results_dir).glob('*_results.csv'):
        protocol, gateway = file.stem.split('_')[:2]
        if protocol not in results:
            results[protocol] = {}
        results[protocol][gateway] = pd.read_csv(file)
    return results

def analyze_metrics(results):
    """Analisa métricas importantes dos resultados."""
    metrics = {}
    for protocol, gateways in results.items():
        metrics[protocol] = {}
        for gateway, data in gateways.items():
            metrics[protocol][gateway] = {
                'mean_latency': data['latency'].mean(),
                'p95_latency': data['latency'].quantile(0.95),
                'p99_latency': data['latency'].quantile(0.99),
                'throughput': data['requests_per_second'].mean(),
                'error_rate': (data['errors'] / data['total']).mean() if 'errors' in data.columns else 0
            }
    return metrics

def generate_comparison_plots(metrics, output_dir):
    """Gera gráficos comparativos entre Ingress Controller e API Gateway."""
    metrics_to_plot = ['mean_latency', 'p95_latency', 'p99_latency', 'throughput', 'error_rate']
    
    for metric in metrics_to_plot:
        plt.figure(figsize=(12, 6))
        data = []
        labels = []
        
        for protocol in metrics:
            ingress_value = metrics[protocol]['ingress'][metric]
            api_value = metrics[protocol]['api-gateway'][metric]
            data.extend([ingress_value, api_value])
            labels.extend([f'{protocol}\nIngress', f'{protocol}\nAPI Gateway'])
        
        plt.bar(labels, data)
        plt.title(f'Comparison of {metric.replace("_", " ").title()}')
        plt.xticks(rotation=45)
        plt.tight_layout()
        plt.savefig(f'{output_dir}/{metric}_comparison.png')
        plt.close()

def generate_report(metrics, output_dir):
    """Gera um relatório detalhado em JSON."""
    report = {
        'summary': {},
        'detailed_metrics': metrics
    }
    
    # Calcular médias gerais
    for metric in ['mean_latency', 'p95_latency', 'p99_latency', 'throughput', 'error_rate']:
        ingress_values = [metrics[protocol]['ingress'][metric] for protocol in metrics]
        api_values = [metrics[protocol]['api-gateway'][metric] for protocol in metrics]
        
        report['summary'][metric] = {
            'ingress_controller': {
                'mean': sum(ingress_values) / len(ingress_values),
                'min': min(ingress_values),
                'max': max(ingress_values)
            },
            'api_gateway': {
                'mean': sum(api_values) / len(api_values),
                'min': min(api_values),
                'max': max(api_values)
            }
        }
    
    # Salvar relatório
    with open(f'{output_dir}/analysis_report.json', 'w') as f:
        json.dump(report, f, indent=2)

def main():
    results_dir = 'test-results'
    output_dir = 'analysis-results'
    Path(output_dir).mkdir(exist_ok=True)
    
    # Carregar e analisar resultados
    results = load_test_results(results_dir)
    metrics = analyze_metrics(results)
    
    # Gerar visualizações e relatório
    generate_comparison_plots(metrics, output_dir)
    generate_report(metrics, output_dir)
    
    print(f"Analysis complete. Results available in {output_dir}")

if __name__ == '__main__':
    main() 