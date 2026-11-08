#!/bin/sh
set -eu
case ${1:-server} in
server)
  printf '%s\n' 'Server mode disables system sleep, including the global lid-sleep override.' \
    'Use mains power and ventilation. Do not put the running Mac in a closed bag.' \
    'The lid override is macOS-version-dependent: test physical lid close after deployment.'
  sudo /usr/bin/pmset -c sleep 0 disksleep 0 womp 1 autorestart 1
  sudo /usr/bin/pmset -a disablesleep 1
  ;;
portable)
  sudo /usr/bin/pmset -a disablesleep 0
  sudo /usr/bin/pmset -c sleep 10 disksleep 10
  printf '%s\n' 'System sleep re-enabled; automatic restart after power loss remains enabled.'
  ;;
*)
  printf 'Usage: %s [server|portable]\n' "$0" >&2
  exit 2
  ;;
esac
/usr/bin/pmset -g custom
/usr/bin/pmset -g
