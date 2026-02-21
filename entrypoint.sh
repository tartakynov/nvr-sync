#!/bin/bash
set -euo pipefail

CRON_SCHEDULE="${CRON_SCHEDULE:-0 2 * * *}"

echo "$CRON_SCHEDULE /usr/local/bin/ssd-to-hdd.sh sync >> /proc/1/fd/1 2>&1" > /etc/crontabs/root

exec crond -f -l 2
