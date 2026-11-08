#!/bin/sh
set -eu

# EOF is unexpected for a live stream, even when the producer exits zero.
exec /bin/bash -e -o pipefail -c '
  /usr/bin/log stream --info --style syslog --predicate '\''process == "postfix" OR process == "master" OR process == "pickup" OR process == "cleanup" OR process == "qmgr" OR process == "smtp" OR process == "bounce" OR process == "defer" OR process == "local"'\'' |
    while IFS= read -r line; do
      printf "%s\n" "$line" >>/var/log/services/postfix.log || exit 1
    done
  exit 1
'
