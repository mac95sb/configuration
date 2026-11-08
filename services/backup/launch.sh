#!/bin/sh
# Deployed by services/security with the rest of the root-controlled runtime.
set -eu
[ "$#" -gt 0 ] || set -- backup
case $1 in
backup | init | checkpoint | restore | verify | prune) ;;
*)
  echo 'Allowed commands: backup init checkpoint restore verify prune' >&2
  exit 2
  ;;
esac
[ "$(/usr/bin/id -u)" = 0 ] || {
  echo 'Root is required.' >&2
  exit 1
}
cd /var/empty
/usr/local/bin/python3 -I -c '
import pathlib
for name in ("/etc/fnox", "/etc/fnox/config.toml", "/etc/fnox/operational.key",
             "/usr/local", "/usr/local/bin", "/usr/local/libexec", "/usr/local/libexec/mac-server",
             "/usr/local/libexec/mac-server/backup", "/usr/local/libexec/mac-server/backup/coordinator.py",
             "/usr/local/libexec/mac-server/backup/courier.py",
             "/usr/local/bin/python3", "/usr/local/bin/fnox", "/usr/local/bin/age", "/usr/local/bin/restic",
             "/usr/local/bin/rclone", "/usr/local/bin/pitchfork"):
    p = pathlib.Path(name)
    s = p.lstat()
    mask = 0o077 if name.startswith("/etc/fnox") else 0o022
    if p.is_symlink() or s.st_uid != 0 or s.st_mode & mask:
        raise SystemExit("Unsafe privileged runtime: " + name)
'
exec /usr/bin/env -i PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  HOME=/var/root USER=root LOGNAME=root FNOX_AGE_KEY_FILE=/etc/fnox/operational.key \
  /usr/local/bin/fnox exec --non-interactive --no-daemon \
  --config /etc/fnox/config.toml --profile backup -- \
  /usr/local/bin/python3 -I /usr/local/libexec/mac-server/backup/coordinator.py "$@"
