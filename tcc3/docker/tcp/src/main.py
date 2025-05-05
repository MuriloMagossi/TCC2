import asyncio
import json
from prometheus_client import Counter, start_http_server
import structlog
import signal
import sys
from typing import Dict, Set
import threading

# Configuração do logger
logger = structlog.get_logger()

# Métricas Prometheus
tcp_connections_total = Counter('tcp_connections_total', 'Total number of TCP connections')
tcp_messages_total = Counter('tcp_messages_total', 'Total number of TCP messages', ['direction'])

# Armazenamento de conexões ativas
clients: Set[asyncio.StreamWriter] = set()

async def handle_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    """Manipula uma conexão TCP."""
    # Registra nova conexão
    clients.add(writer)
    tcp_connections_total.inc()
    addr = writer.get_extra_info('peername')
    logger.info("client_connected", addr=addr)

    try:
        while True:
            # Lê dados do cliente
            data = await reader.read(1024)
            if not data:
                break

            # Processa a mensagem
            message = data.decode()
            tcp_messages_total.labels(direction="received").inc()
            logger.info("message_received", addr=addr, message=message)

            try:
                # Tenta parsear como JSON
                json_data = json.loads(message)
                response = json.dumps({"status": "ok", "echo": json_data})
            except json.JSONDecodeError:
                # Se não for JSON, faz echo do texto
                response = f"Echo: {message}"

            # Envia resposta
            writer.write(response.encode())
            await writer.drain()
            tcp_messages_total.labels(direction="sent").inc()
            logger.info("message_sent", addr=addr, response=response)

    except Exception as e:
        logger.error("client_error", addr=addr, error=str(e))
    finally:
        # Limpa recursos
        writer.close()
        await writer.wait_closed()
        clients.remove(writer)
        logger.info("client_disconnected", addr=addr)

async def shutdown(signal: signal.Signals, loop: asyncio.AbstractEventLoop) -> None:
    """Realiza o desligamento gracioso do servidor."""
    logger.info("shutdown_initiated", signal=signal.name)
    
    # Fecha todas as conexões ativas
    for client in clients:
        client.close()
        await client.wait_closed()
    
    # Para o event loop
    loop.stop()

def run_metrics_server() -> None:
    """Inicia o servidor de métricas do Prometheus."""
    start_http_server(8081)
    logger.info("metrics_server_started", port=8081)

async def main() -> None:
    """Função principal do servidor TCP."""
    # Inicia servidor de métricas em uma thread separada
    metrics_thread = threading.Thread(target=run_metrics_server)
    metrics_thread.start()

    # Configura o servidor TCP
    server = await asyncio.start_server(
        handle_client,
        '0.0.0.0',
        5000
    )
    
    addr = server.sockets[0].getsockname()
    logger.info("server_started", addr=addr)

    # Configura handlers para sinais de término
    loop = asyncio.get_event_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(
            sig,
            lambda s=sig: asyncio.create_task(shutdown(s, loop))
        )

    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("server_stopped", reason="keyboard_interrupt")
    sys.exit(0) 