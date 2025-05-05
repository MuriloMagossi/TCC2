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

class HTTPTest(BaseTest):
    def __init__(self):
        super().__init__("http")

    def test_protocol(self, host: str, port: int) -> tuple[bool, float, str]:
        """Test HTTP protocol implementation"""
        url = f"http://{host}:{port}/http"
        
        try:
            start_time = time.time()
            response = requests.get(url)
            end_time = time.time()
            
            if response.status_code == 200:
                return True, end_time - start_time, ""
            else:
                return False, 0.0, f"HTTP {response.status_code}: {response.text}"
                
        except Exception as e:
            return False, 0.0, str(e)

if __name__ == "__main__":
    # Run tests for 100 iterations
    test = HTTPTest()
    results = test.run_tests(100)
    test.print_results(results) 