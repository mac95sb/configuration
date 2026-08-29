#!/bin/sh
set -eu

# Wait for Wi-Fi because cloudflared exits when the edge is unavailable at boot.
config=/Users/mac/Developer/configuration/services/cloudflared/config.yml
edge_host=region1.v2.argotunnel.com
edge_port=7844

attempt=0
until nc -z -G 3 "$edge_host" "$edge_port" >/dev/null 2>&1; do
	attempt=$((attempt + 1))
	if [ "$attempt" -ge 150 ]; then
		printf 'cloudflared: %s:%s unreachable after 5 minutes\n' "$edge_host" "$edge_port" >&2
		exit 1
	fi
	sleep 2
done

exec /usr/local/bin/cloudflared --config "$config" tunnel run
