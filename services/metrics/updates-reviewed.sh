#!/bin/sh
set -eu

# Run only after a human completes the infrastructure update review.
# Never schedule this writer automatically: freshness must reflect that review.
output=${METRICS_FILE:-/Users/svc_observability/textfile/updates.prom}
tmp=$(mktemp "$output.XXXXXX")
trap 'rm -f "$tmp"' EXIT HUP INT TERM
cat >"$tmp" <<EOF
# HELP infrastructure_updates_last_review_seconds Unix time of the last completed infrastructure update review.
# TYPE infrastructure_updates_last_review_seconds gauge
infrastructure_updates_last_review_seconds $(date +%s)
EOF
chmod 0640 "$tmp"
mv "$tmp" "$output"
