#!/bin/sh
set -eu
# Fail preflight instead of reporting success with every restic fixture skipped.
restic=${TEST_RESTIC:-restic}
"$restic" version >/dev/null || {
  printf '%s\n' 'Restic is required: install it or set TEST_RESTIC to its executable.' >&2
  exit 1
}
exec /usr/bin/env python3 "$(dirname "$0")/test_backup.py" "$@"
