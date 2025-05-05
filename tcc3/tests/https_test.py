from base_test import BaseTest
import requests
import time
import urllib3

# Disable SSL warnings for testing
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class HTTPSTest(BaseTest):
    def __init__(self):
        super().__init__("https")

    def test_protocol(self, host: str, port: int) -> tuple[bool, float, str]:
        """Test HTTPS protocol implementation"""
        url = f"https://{host}:{port}/https"
        
        try:
            start_time = time.time()
            response = requests.get(url, verify=False)  # Disable SSL verification for testing
            end_time = time.time()
            
            if response.status_code == 200:
                return True, end_time - start_time, ""
            else:
                return False, 0.0, f"HTTPS {response.status_code}: {response.text}"
                
        except Exception as e:
            return False, 0.0, str(e)

if __name__ == "__main__":
    # Run tests for 100 iterations
    test = HTTPSTest()
    results = test.run_tests(100)
    test.print_results(results) 