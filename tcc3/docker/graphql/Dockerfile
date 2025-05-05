FROM tcc3-base:latest

# Instalar dependências específicas do GraphQL
RUN pip install --no-cache-dir strawberry-graphql==0.219.1

# Copiar código fonte do serviço GraphQL
COPY src/ .

# Expor porta GraphQL
EXPOSE 8082

# Comando para iniciar o serviço GraphQL
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8082"] 