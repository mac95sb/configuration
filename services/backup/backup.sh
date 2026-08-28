#!/bin/sh
set -eu

repo=/Users/mac/Developer/configuration
staging=${BACKUP_STAGING:-/Users/svc_backup/backup-staging}
remote=${BACKUP_REMOTE-R2:home-backups}
metrics_dir=${BACKUP_METRICS_DIR-/Users/svc_observability/textfile}
stamp=$(date +%F)

# awk, not a TOML parser: taplo is a user tool and not on a service PATH.
sources=$(awk '
  function flush() { if (n != "") printf "%s\t%s\t%s\n", n, k, p; n = ""; k = ""; p = "" }
  function val() { match($0, /"[^"]*"/); return substr($0, RSTART + 1, RLENGTH - 2) }
  /^\[sources\./ { flush(); n = $0; gsub(/^\[sources\.|\]$/, "", n); next }
  /^\[/          { flush(); next }
  /^kind *=/     { k = val(); next }
  /^path *=/     { p = val(); next }
  END            { flush() }
' "$repo/services/backup/manifest.toml")

work=$(mktemp -d "${TMPDIR:-/tmp}/backup.XXXXXX")
grep -Eo 'age1[a-z0-9]+' "$repo/fnox.toml" | sort -u >"$work/recipients"
archive_tmp=
trap 'rm -rf "$work"; [ -z "$archive_tmp" ] || rm -f "$archive_tmp"' EXIT HUP INT TERM

printf '%s\n' "$sources" | while IFS="$(printf '\t')" read -r name kind path; do
  [ -n "$name" ] || continue
  if [ ! -e "$path" ]; then
    printf 'skipping %s: %s is missing\n' "$name" "$path"
    continue
  fi

  case $kind in
  git-bundle) git -c safe.directory="$path" -C "$path" bundle create "$work/$name.bundle" --all ;;
  sqlite) sqlite3 "$path" ".backup '$work/$name.db'" ;;
  directory) tar czf "$work/$name.tar.gz" -C "$(dirname "$path")" "$(basename "$path")" ;;
  *)
    printf 'unknown kind %s for %s\n' "$kind" "$name" >&2
    exit 1
    ;;
  esac
done

mkdir -p "$staging/daily" "$staging/weekly" "$staging/monthly"
archive=$staging/daily/$stamp.tar.gz.age
archive_tmp=$(mktemp "$staging/daily/.$stamp.tar.gz.age.XXXXXX")
tar czf - -C "$work" . | /usr/local/bin/age -R "$work/recipients" -o "$archive_tmp"
chmod 640 "$archive_tmp"
mv "$archive_tmp" "$archive"

# Unencrypted so a rebuild can clone before any key exists; fnox.toml is ciphertext.
if [ -f "$work/configuration.bundle" ]; then
  cp "$work/configuration.bundle" "$staging/configuration-latest.bundle"
fi

# Hard links, so a weekly or monthly costs no extra bytes.
if [ "$(date +%u)" = 7 ]; then
  ln -f "$archive" "$staging/weekly/$stamp.tar.gz.age"
  # Last Sunday of the month: adding a week lands in the next one.
  if [ "$(date -v+7d +%m)" != "$(date +%m)" ]; then
    ln -f "$archive" "$staging/monthly/$stamp.tar.gz.age"
  fi
fi

"$repo/services/backup/prune.sh" "$staging"

if [ -n "$remote" ]; then
  /usr/local/bin/rclone sync "$staging" "$remote"
fi

metric=backup_last_success_seconds
if [ -n "$metrics_dir" ]; then
  printf '%s %s\n' "$metric" "$(date +%s)" >"$metrics_dir/$metric.tmp"
  mv "$metrics_dir/$metric.tmp" "$metrics_dir/$metric.prom"
fi

printf 'backup complete: %s\n' "$archive"
