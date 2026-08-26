#!/bin/sh
set -eu

# Runs as `mac`: a svc_* daemon cannot write to iCloud Drive. Moves sealed
# archives only — `mac` is not in the fnox group and cannot decrypt them.
staging=/Users/svc_backup/backup-staging
destination=$HOME/Library/Mobile\ Documents/com~apple~CloudDocs/Backups

mkdir -p "$destination"
rsync -a --delete "$staging/" "$destination/"
metric=backup_courier_last_success_seconds
metrics_dir=/Users/svc_observability/textfile
printf '%s %s\n' "$metric" "$(date +%s)" >"$metrics_dir/$metric.tmp"
mv "$metrics_dir/$metric.tmp" "$metrics_dir/$metric.prom"

printf 'couriered to %s\n' "$destination"
