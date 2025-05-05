import time
from abc import ABC, abstractmethod
from typing import Dict, Any, Tuple

class BaseTest(ABC):
    def __init__(self, protocol: str):
        self.protocol = protocol
        self.ingress_port = self._get_ingress_port()
        self.gateway_port = self._get_gateway_port()

    def _get_ingress_port(self) -> int:
        """Get the Ingress Controller port for the protocol"""
        ports = {
            "http": 30080,
            "https": 30443,
            "websocket": 30081,
            "graphql": 30082,
            "tcp": 30000
        }
        return ports.get(self.protocol, 30080)

    def _get_gateway_port(self) -> int:
        """Get the API Gateway port for the protocol"""
        ports = {
            "http": 8000,
            "https": 8443,
            "websocket": 8001,
            "graphql": 8002,
            "tcp": 9000
        }
        return ports.get(self.protocol, 8000)

    @abstractmethod
    def test_protocol(self, host: str, port: int) -> Tuple[bool, float, str]:
        """Test the protocol implementation
        
        Args:
            host: The host to test against
            port: The port to test against
            
        Returns:
            Tuple containing:
            - Success status (bool)
            - Response time in seconds (float)
            - Error message if any (str)
        """
        pass

    def test_ingress(self) -> Tuple[bool, float, str]:
        """Test the Ingress Controller implementation"""
        return self.test_protocol("localhost", self.ingress_port)

    def test_gateway(self) -> Tuple[bool, float, str]:
        """Test the API Gateway implementation"""
        return self.test_protocol("localhost", self.gateway_port)

    def run_tests(self, iterations: int = 100) -> Dict[str, Any]:
        """Run tests for both Ingress Controller and API Gateway
        
        Args:
            iterations: Number of test iterations to run
            
        Returns:
            Dictionary containing test results
        """
        results = {
            "ingress": {
                "success": 0,
                "total_time": 0.0,
                "errors": []
            },
            "gateway": {
                "success": 0,
                "total_time": 0.0,
                "errors": []
            }
        }

        # Run Ingress Controller tests
        for _ in range(iterations):
            success, time_taken, error = self.test_ingress()
            if success:
                results["ingress"]["success"] += 1
                results["ingress"]["total_time"] += time_taken
            else:
                results["ingress"]["errors"].append(error)

        # Run API Gateway tests
        for _ in range(iterations):
            success, time_taken, error = self.test_gateway()
            if success:
                results["gateway"]["success"] += 1
                results["gateway"]["total_time"] += time_taken
            else:
                results["gateway"]["errors"].append(error)

        # Calculate averages
        if results["ingress"]["success"] > 0:
            results["ingress"]["avg_time"] = results["ingress"]["total_time"] / results["ingress"]["success"]
        else:
            results["ingress"]["avg_time"] = 0.0

        if results["gateway"]["success"] > 0:
            results["gateway"]["avg_time"] = results["gateway"]["total_time"] / results["gateway"]["success"]
        else:
            results["gateway"]["avg_time"] = 0.0

        return results

    def print_results(self, results: Dict[str, Any]):
        """Print test results in a readable format"""
        print(f"\n{self.protocol.upper()} Test Results")
        print("=" * 50)
        
        print("\nIngress Controller:")
        print(f"  Success Rate: {(results['ingress']['success'] / 100) * 100:.1f}%")
        print(f"  Average Response Time: {results['ingress']['avg_time']*1000:.2f}ms")
        if results["ingress"]["errors"]:
            print("  Errors:")
            for error in results["ingress"]["errors"]:
                print(f"    - {error}")
        
        print("\nAPI Gateway:")
        print(f"  Success Rate: {(results['gateway']['success'] / 100) * 100:.1f}%")
        print(f"  Average Response Time: {results['gateway']['avg_time']*1000:.2f}ms")
        if results["gateway"]["errors"]:
            print("  Errors:")
            for error in results["gateway"]["errors"]:
                print(f"    - {error}")
        
        print("\n" + "=" * 50) 