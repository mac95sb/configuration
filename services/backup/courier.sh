#!/bin/sh
set -eu
# Separate unprivileged entrypoint: the root launcher does not accept courier.
exec /usr/local/bin/python3 -I /usr/local/libexec/mac-server/backup/courier.py "$@"
