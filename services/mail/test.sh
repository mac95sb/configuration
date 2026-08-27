#!/bin/sh

set -eu

recipient=${1:-maclong9@icloud.com}

printf '%s\n' \
  'This is a direct-delivery test from the maclong.dev server.' \
  "Sent at $(date -u '+%Y-%m-%d %H:%M:%S UTC')." |
  /usr/bin/mail -v -s 'maclong.dev mail test' "$recipient"

printf '%s\n' "Queued a test message for $recipient."

attempt=0
while ! queue=$(/usr/bin/mailq 2>&1); do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 10 ]; then
    printf '%s\n' "$queue" >&2
    exit 1
  fi
  sleep 1
done

printf '%s\n' "$queue"
