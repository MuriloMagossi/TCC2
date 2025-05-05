import subprocess
import sys

def install_dependencies():
    """Install required dependencies if not already installed"""
    required_packages = {
        'urllib3': '2.1.0'  # TCP test doesn't need external packages, but we keep urllib3 for consistency
    }
    
    for package, version in required_packages.items():
        try:
            __import__(package)
        except ImportError:
            print(f"Installing {package}...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", f"{package}=={version}"])

# Install dependencies before importing them
install_dependencies()

import socket
import time
from base_test import BaseTest

class TCPTest(BaseTest):
    def __init__(self):
        super().__init__("tcp")

    def test_protocol(self, host: str, port: int) -> tuple[bool, float, str]:
        """Test TCP protocol implementation"""
        try:
            start_time = time.time()
            
            # Create TCP socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)  # 5 second timeout
            
            # Connect to server
            sock.connect((host, port))
            
            # Send test message
            sock.sendall(b"ping")
            
            # Receive response
            response = sock.recv(1024)
            end_time = time.time()
            
            # Close socket
            sock.close()
            
            if response == b"pong":
                return True, end_time - start_time, ""
            else:
                return False, 0.0, f"Unexpected response: {response}"
                
        except Exception as e:
            return False, 0.0, str(e)

if __name__ == "__main__":
    # Run tests for 100 iterations
    test = TCPTest()
    results = test.run_tests(100)
    test.print_results(results) 