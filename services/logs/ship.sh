#!/bin/sh
set -eu

# Compatibility entry point: fail closed instead of hiding a partial failure.
# Prefer separate supervised daemons running each ship-*.sh script.
base=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
/bin/sh "$base/ship-pitchfork.sh" &
pitchfork_pid=$!
/bin/sh "$base/ship-postfix.sh" &
postfix_pid=$!
trap 'kill "$pitchfork_pid" "$postfix_pid" 2>/dev/null || :; wait || :' EXIT
trap 'exit 1' HUP INT TERM
while kill -0 "$pitchfork_pid" 2>/dev/null && kill -0 "$postfix_pid" 2>/dev/null; do
  sleep 1
done
printf 'log stream exited; restarting both streams (use separate supervised daemons)\n' >&2
exit 1
