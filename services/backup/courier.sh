#!/bin/sh
set -eu

# Run as mac for iCloud access; this account cannot decrypt the archives.
staging=/Users/svc_backup/backup-staging
destination=$HOME/Library/Mobile\ Documents/com~apple~CloudDocs/Backups/configuration

mkdir -p "$destination"
rsync -a --delete "$staging/" "$destination/"
metric=backup_courier_last_success_seconds
metrics_dir=/Users/svc_observability/textfile
printf '%s %s\n' "$metric" "$(date +%s)" >"$metrics_dir/$metric.tmp"
mv "$metrics_dir/$metric.tmp" "$metrics_dir/$metric.prom"

printf 'couriered to %s\n' "$destination"
