#!/bin/sh

set -eu

public_ipv4=$(curl -4 -fsS --max-time 10 https://cloudflare.com/cdn-cgi/trace |
  awk -F= '$1 == "ip" { print $2; exit }')

case $public_ipv4 in
'' | *[!0-9.]*)
  printf '%s\n' 'Could not determine the server public IPv4 address.' >&2
  exit 1
  ;;
esac

printf '%s\n' \
  "A    mail       $public_ipv4" \
  "TXT  @          v=spf1 ip4:$public_ipv4 include:icloud.com ~all" \
  'TXT  _dmarc     v=DMARC1; p=none'
