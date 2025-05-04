FROM node:18-alpine

WORKDIR /app

COPY server.js package.json ./

RUN npm install

EXPOSE 9000

CMD ["node", "server.js"] 