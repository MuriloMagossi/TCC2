# Dockerfile para servidor TCP echo puro
FROM alpine:latest

RUN apk add --no-cache socat

EXPOSE 9000

CMD ["socat", "tcp-listen:9000,reuseaddr,fork", "system:/bin/cat"] 