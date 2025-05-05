import subprocess
import sys

def install_dependencies():
    """Install required dependencies if not already installed"""
    required_packages = {
        'websockets': '12.0'
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
import websockets
import asyncio
import time
from typing import Dict, Any

class WebSocketTest(BaseTest):
    def __init__(self):
        super().__init__("websocket")

    def get_ingress_url(self, path: str = "") -> str:
        return f"ws://{self.ingress_host}:{self.ingress_port}/{self.protocol}{path}"

    def get_gateway_url(self, path: str = "") -> str:
        return f"ws://{self.gateway_host}:{self.gateway_port}/{self.protocol}{path}"

    async def _test_websocket(self, host: str, port: int) -> tuple[bool, float, str]:
        """Test WebSocket protocol implementation"""
        url = f"ws://{host}:{port}/websocket"
        
        try:
            start_time = time.time()
            async with websockets.connect(url) as websocket:
                # Send a test message
                await websocket.send("ping")
                
                # Wait for response
                response = await websocket.recv()
                end_time = time.time()
                
                if response == "pong":
                    return True, end_time - start_time, ""
                else:
                    return False, 0.0, f"Unexpected response: {response}"
                    
        except Exception as e:
            return False, 0.0, str(e)

    def test_protocol(self, host: str, port: int) -> tuple[bool, float, str]:
        """Run WebSocket test in an event loop"""
        return asyncio.run(self._test_websocket(host, port))

    def test_ingress(self) -> Dict[str, Any]:
        """Test WebSocket service through Ingress Controller"""
        try:
            return asyncio.run(self._test_websocket(self.ingress_host, self.ingress_port))
        except Exception as e:
            return {"success": False, "error": str(e)}

    def test_gateway(self) -> Dict[str, Any]:
        """Test WebSocket service through API Gateway"""
        try:
            return asyncio.run(self._test_websocket(self.gateway_host, self.gateway_port))
        except Exception as e:
            return {"success": False, "error": str(e)}

if __name__ == "__main__":
    # Run tests for 100 iterations
    test = WebSocketTest()
    results = test.run_tests(100)
    test.print_results(results) 