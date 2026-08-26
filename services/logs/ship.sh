#!/bin/sh
set -eu

# pitchfork stores daemon logs in SQLite; Alloy tails files. `-n 0` skips the backlog.
log=/var/log/services/pitchfork.log

# Reopen per line so newsyslog rotation is not defeated by a held descriptor.
/usr/local/bin/pitchfork logs -n 0 --tail --no-pager |
  while IFS= read -r line; do
    printf '%s\n' "$line" >>"$log"
  done
