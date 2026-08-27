#!/bin/sh
set -eu

repo=/Users/mac/Developer/configuration
forgejo_work=/Users/svc_forgejo/forgejo-data
grafana_data=/Users/svc_observability/grafana-data
verify_only=false
if [ "${1:-}" = --verify ]; then
  verify_only=true
elif [ "$#" -ne 0 ]; then
  printf 'Usage: %s [--verify]\n' "$0" >&2
  exit 2
fi

if [ "$verify_only" = false ] &&
  { [ -e "$forgejo_work/data/forgejo.db" ] || [ -e "$grafana_data/grafana.db" ]; }; then
  printf '%s\n' 'restore skipped: live service data already exists'
  exit 0
fi

restore=$(mktemp -d /private/tmp/home-restore.XXXXXX)
cleanup() {
  sudo -u svc_backup rm -rf "$restore"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
sudo chown svc_backup:staff "$restore"
sudo chmod 750 "$restore"

archive_name=$(sudo -u svc_backup /usr/local/bin/fnox exec \
  --config "$repo/fnox.toml" --profile backup -- \
  /usr/local/bin/rclone lsf --files-only R2:home-backups/daily |
  grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}[.]tar[.]gz[.]age$' | sort | tail -n 1)

case $archive_name in
????-??-??.tar.gz.age) ;;
*)
  printf '%s\n' 'No dated service backup was found in R2.' >&2
  exit 1
  ;;
esac

printf 'Restoring service state from %s\n' "$archive_name"
sudo -u svc_backup /usr/local/bin/fnox exec \
  --config "$repo/fnox.toml" --profile backup -- \
  /usr/local/bin/rclone copyto "R2:home-backups/daily/$archive_name" "$restore/archive.age"
sudo -u svc_backup /usr/local/bin/age -d -i /etc/fnox/operational.key \
  -o "$restore/archive.tar.gz" "$restore/archive.age"
sudo -u svc_backup tar -xzf "$restore/archive.tar.gz" -C "$restore"

for required in configuration.bundle robin.bundle forgejo-db.db forgejo-repositories.tar.gz grafana-db.db; do
  if [ ! -f "$restore/$required" ]; then
    printf 'Backup is incomplete: %s is missing.\n' "$required" >&2
    exit 1
  fi
done
if ! sudo -u svc_backup git clone --quiet \
  "$restore/configuration.bundle" "$restore/verify-configuration" ||
  ! sudo -u svc_backup git clone --quiet \
    "$restore/robin.bundle" "$restore/verify-robin"; then
  printf '%s\n' 'Backup contains an invalid Git bundle.' >&2
  exit 1
fi
if ! sudo -u svc_backup tar -tzf \
  "$restore/forgejo-repositories.tar.gz" >/dev/null; then
  printf '%s\n' 'Backup contains an invalid Forgejo repository archive.' >&2
  exit 1
fi
if [ "$(sudo -u svc_backup sqlite3 "$restore/forgejo-db.db" 'pragma integrity_check')" != ok ] ||
  [ "$(sudo -u svc_backup sqlite3 "$restore/grafana-db.db" 'pragma integrity_check')" != ok ]; then
  printf '%s\n' 'Backup contains an invalid SQLite database.' >&2
  exit 1
fi

if [ "$verify_only" = true ]; then
  printf 'Verified recovery archive %s\n' "$archive_name"
  exit 0
fi

sudo install -d -m 750 -o svc_forgejo -g staff "$forgejo_work"
sudo install -d -m 755 -o svc_forgejo -g staff "$forgejo_work/data"
sudo -u svc_forgejo tar -xzf "$restore/forgejo-repositories.tar.gz" -C "$forgejo_work/data"
sudo install -m 640 -o svc_forgejo -g staff "$restore/forgejo-db.db" "$forgejo_work/data/forgejo.db"
sudo -u svc_forgejo rm -f \
  "$forgejo_work/data/forgejo.db-wal" "$forgejo_work/data/forgejo.db-shm"

sudo install -d -m 750 -o svc_observability -g staff "$grafana_data"
sudo install -m 640 -o svc_observability -g staff "$restore/grafana-db.db" "$grafana_data/grafana.db"

if [ ! -d /Users/mac/Developer/robin/.git ] && [ -f "$restore/robin.bundle" ]; then
  mkdir -p /Users/mac/Developer
  git clone "$restore/robin.bundle" /Users/mac/Developer/robin
  git -C /Users/mac/Developer/robin remote set-url origin git@git.maclong.dev:mac/robin.git
fi

printf 'Restored Forgejo and Grafana from %s\n' "$archive_name"
