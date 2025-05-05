import subprocess
import sys

def install_dependencies():
    """Install required dependencies if not already installed"""
    required_packages = {
        'requests': '2.31.0',
        'websockets': '12.0',
        'urllib3': '2.1.0'
    }
    
    for package, version in required_packages.items():
        try:
            __import__(package)
        except ImportError:
            print(f"Installing {package}...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", f"{package}=={version}"])

# Install dependencies before importing them
install_dependencies()

import json
from datetime import datetime
from http_test import HTTPTest
from https_test import HTTPSTest
from websocket_test import WebSocketTest
from graphql_test import GraphQLTest
from tcp_test import TCPTest

def run_all_tests(iterations: int = 100) -> dict:
    """Run all protocol tests and collect results"""
    results = {
        "timestamp": datetime.now().isoformat(),
        "iterations": iterations,
        "protocols": {}
    }

    # Run HTTP tests
    print("\nRunning HTTP tests...")
    http_test = HTTPTest()
    results["protocols"]["http"] = http_test.run_tests(iterations)
    http_test.print_results(results["protocols"]["http"])

    # Run HTTPS tests
    print("\nRunning HTTPS tests...")
    https_test = HTTPSTest()
    results["protocols"]["https"] = https_test.run_tests(iterations)
    https_test.print_results(results["protocols"]["https"])

    # Run WebSocket tests
    print("\nRunning WebSocket tests...")
    websocket_test = WebSocketTest()
    results["protocols"]["websocket"] = websocket_test.run_tests(iterations)
    websocket_test.print_results(results["protocols"]["websocket"])

    # Run GraphQL tests
    print("\nRunning GraphQL tests...")
    graphql_test = GraphQLTest()
    results["protocols"]["graphql"] = graphql_test.run_tests(iterations)
    graphql_test.print_results(results["protocols"]["graphql"])

    # Run TCP tests
    print("\nRunning TCP tests...")
    tcp_test = TCPTest()
    results["protocols"]["tcp"] = tcp_test.run_tests(iterations)
    tcp_test.print_results(results["protocols"]["tcp"])

    return results

def save_results(results: dict, filename: str = "test_results.json"):
    """Save test results to a JSON file"""
    with open(filename, "w") as f:
        json.dump(results, f, indent=2)

def print_summary(results: dict):
    """Print a summary of all test results"""
    print("\nTest Summary")
    print("=" * 50)
    print(f"Timestamp: {results['timestamp']}")
    print(f"Iterations per test: {results['iterations']}")
    print("\nProtocol Results:")
    
    for protocol, data in results["protocols"].items():
        print(f"\n{protocol.upper()}:")
        print(f"  Ingress Controller:")
        print(f"    Success Rate: {(data['ingress']['success'] / results['iterations']) * 100:.1f}%")
        print(f"    Average Response Time: {data['ingress']['avg_time']*1000:.2f}ms")
        
        print(f"  API Gateway:")
        print(f"    Success Rate: {(data['gateway']['success'] / results['iterations']) * 100:.1f}%")
        print(f"    Average Response Time: {data['gateway']['avg_time']*1000:.2f}ms")

if __name__ == "__main__":
    # Run all tests
    results = run_all_tests(iterations=100)
    
    # Save results to file
    save_results(results)
    
    # Print summary
    print_summary(results) 