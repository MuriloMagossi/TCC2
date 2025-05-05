FROM tcc3-base:latest

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório para certificados SSL
RUN mkdir -p /app/certs

# Instalar dependências específicas do HTTPS
RUN pip install --no-cache-dir requests==2.31.0 pyOpenSSL==23.3.0

# Copiar código fonte do serviço HTTPS
COPY src/ .

# Expor porta HTTPS
EXPOSE 8443

# Comando para iniciar o serviço HTTPS
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8443", "--ssl-keyfile", "/app/certs/key.pem", "--ssl-certfile", "/app/certs/cert.pem"] 