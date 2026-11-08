#!/bin/sh
set -eu
[ "$#" = 0 ] || exit 64
[ "$(/usr/bin/id -u)" = 0 ] || exit 77
cd /var/empty
exec /usr/bin/env -i PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  HOME=/var/root USER=root LOGNAME=root PITCHFORK_USER=root PITCHFORK_SUPERVISOR_AUTO_START=false \
  /usr/local/bin/python3 -I -S /usr/local/libexec/mac-server/ship_pitchfork.py
