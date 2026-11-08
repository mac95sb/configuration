#!/bin/sh
set -eu

# Let cloudflared handle edge discovery and connection retries.
exec /usr/local/bin/cloudflared --config /Users/mac/Developer/configuration/services/cloudflared/config.yml tunnel run
