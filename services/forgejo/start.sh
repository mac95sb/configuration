#!/bin/sh
set -eu

work_path="/Users/svc_forgejo/forgejo-data"
config="$work_path/app.ini"

mkdir -p "$work_path"
install -m 600 /Users/mac/Developer/configuration/services/forgejo/app.ini "$config"
cat >>"$config" <<-EOF

	[security]
	SECRET_KEY = ${FORGEJO__SECURITY__SECRET_KEY}
	INTERNAL_TOKEN = ${FORGEJO__SECURITY__INTERNAL_TOKEN}
EOF

exec /usr/local/bin/forgejo web --work-path "$work_path" --custom-path /Users/mac/Developer/configuration/services/forgejo/custom --config "$config"
