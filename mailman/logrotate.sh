#!/bin/bash
set -e

while true; do
    sleep "$(( "$(date -d '4:00 tomorrow' +%s)" - "$(date +%s)" ))"
    logrotate /etc/mailman3/logrotate.conf
done
