from flask import Flask, jsonify
import time

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/')
def hello():
    return jsonify({
        "message": "Hello from HTTP service",
        "timestamp": time.time()
    }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080) 