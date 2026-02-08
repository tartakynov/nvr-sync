FROM alpine:latest

RUN apk add --no-cache bash findutils

COPY nvr-sync.sh /usr/local/bin/nvr-sync.sh
RUN chmod +x /usr/local/bin/nvr-sync.sh

COPY crontab /etc/crontabs/root

CMD ["crond", "-f", "-l", "2"]
