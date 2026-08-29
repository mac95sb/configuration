#!/bin/sh
set -eu

pitchfork_log=/var/log/services/pitchfork.log
postfix_log=/var/log/services/postfix.log
postfix_predicate='process == "postfix" OR process == "master" OR process == "pickup" OR process == "cleanup" OR process == "qmgr" OR process == "smtp" OR process == "bounce" OR process == "defer" OR process == "local"'

# Reopen per line so newsyslog can rotate the files.
ship_pitchfork() {
	/usr/local/bin/pitchfork logs -n 0 --tail --no-pager |
		while IFS= read -r line; do
			printf '%s\n' "$line" >>"$pitchfork_log"
		done
}

ship_postfix() {
	/usr/bin/log stream --info --style syslog --predicate "$postfix_predicate" |
		while IFS= read -r line; do
			printf '%s\n' "$line" >>"$postfix_log"
		done
}

ship_pitchfork &
ship_postfix &
wait
