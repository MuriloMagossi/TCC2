import subprocess
import sys

def install_dependencies():
    """Install required dependencies if not already installed"""
    required_packages = {
        'requests': '2.31.0',
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

from base_test import BaseTest
import requests
import time

class GraphQLTest(BaseTest):
    def __init__(self):
        super().__init__("graphql")

    def test_protocol(self, host: str, port: int) -> tuple[bool, float, str]:
        """Test GraphQL protocol implementation"""
        url = f"http://{host}:{port}/graphql"
        
        # Test query
        query = """
        query {
            hello
        }
        """
        
        try:
            start_time = time.time()
            response = requests.post(
                url,
                json={"query": query},
                headers={"Content-Type": "application/json"}
            )
            end_time = time.time()
            
            if response.status_code == 200:
                data = response.json()
                if "data" in data and "hello" in data["data"]:
                    return True, end_time - start_time, ""
                else:
                    return False, 0.0, f"Invalid response format: {data}"
            else:
                return False, 0.0, f"GraphQL {response.status_code}: {response.text}"
                
        except Exception as e:
            return False, 0.0, str(e)

if __name__ == "__main__":
    # Run tests for 100 iterations
    test = GraphQLTest()
    results = test.run_tests(100)
    test.print_results(results) 