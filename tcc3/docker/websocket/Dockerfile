FROM tcc3-base:latest

# Instalar dependências específicas do WebSocket
RUN pip install --no-cache-dir websockets==12.0

# Copiar código fonte do serviço WebSocket
COPY src/ .

# Expor porta WebSocket
EXPOSE 8081

# Comando para iniciar o serviço WebSocket
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8081"] 