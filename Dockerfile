FROM alpine:latest

RUN apk add --no-cache bash findutils

COPY ssd-to-hdd.sh /usr/local/bin/ssd-to-hdd.sh
RUN chmod +x /usr/local/bin/ssd-to-hdd.sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

CMD ["/usr/local/bin/entrypoint.sh"]
