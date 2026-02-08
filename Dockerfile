FROM alpine:latest

RUN apk add --no-cache bash findutils

COPY nvr-sync.sh /usr/local/bin/nvr-sync.sh
RUN chmod +x /usr/local/bin/nvr-sync.sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

CMD ["/usr/local/bin/entrypoint.sh"]
