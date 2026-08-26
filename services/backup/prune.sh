#!/bin/sh
set -eu

staging=$1
cap_kib=${2:-8300781} # 8.5 GB, in 1024-byte blocks.

usage_kib() {
  du -sk "$staging" | awk '{ print $1 }'
}

for tier in daily weekly monthly; do
  find "$staging/$tier" -type f -name '*.tar.gz.age' -print | sort | while IFS= read -r archive; do
    [ "$(usage_kib)" -le "$cap_kib" ] && break
    rm "$archive"
  done
done

if [ "$(usage_kib)" -gt "$cap_kib" ]; then
  printf 'backup staging still exceeds the 8.5 GB cap after pruning archives\n' >&2
  exit 1
fi
