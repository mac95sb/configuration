#!/bin/sh
set -eu

# Reopen per line so newsyslog can rotate the file. pipefail propagates
# producer failures; a normal EOF also exits so the supervisor can restart.
exec /bin/bash -e -o pipefail -c '
  /usr/local/bin/pitchfork logs -n 0 --tail --no-pager |
    while IFS= read -r line; do
      printf "%s\n" "$line" >>/var/log/services/pitchfork.log || exit 1
    done
  exit 1
'
