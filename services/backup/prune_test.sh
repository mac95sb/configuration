#!/bin/sh
set -eu

root=$(mktemp -d "${TMPDIR:-/tmp}/backup-prune.XXXXXX")
trap 'rm -rf "$root"' EXIT HUP INT TERM
mkdir -p "$root/daily" "$root/weekly" "$root/monthly"

for archive in daily/2026-08-01 daily/2026-08-02 weekly/2026-08-03 monthly/2026-08-04; do
  dd if=/dev/zero of="$root/$archive.tar.gz.age" bs=1048576 count=4 2>/dev/null
done

full=$(du -sk "$root" | awk '{ print $1 }')
cap=$((full - 6144))
"$(dirname "$0")/prune.sh" "$root" "$cap"

[ ! -e "$root/daily/2026-08-01.tar.gz.age" ]
[ ! -e "$root/daily/2026-08-02.tar.gz.age" ]
[ -e "$root/weekly/2026-08-03.tar.gz.age" ]
[ -e "$root/monthly/2026-08-04.tar.gz.age" ]
[ "$(du -sk "$root" | awk '{ print $1 }')" -le "$cap" ]
