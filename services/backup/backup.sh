#!/bin/sh
set -eu
exec /usr/local/libexec/mac-server/backup/launch.sh backup "$@"
