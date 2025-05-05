FROM tcc3-base:latest

# Instalar dependências específicas do TCP
RUN pip install --no-cache-dir asyncio==3.4.3

# Copiar código fonte do serviço TCP
COPY src/ .

# Expor porta TCP
EXPOSE 8083

# Comando para iniciar o serviço TCP
CMD ["python", "main.py"] 