#!/bin/sh
# Run from a trusted temporary checkout OUTSIDE ~/Developer on a new Mac.
set -eu
umask 077
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  printf 'Usage: sh %s CAPSULE.tar.age AGE_IDENTITY FULL_SNAPSHOT_ID CAPSULE_SHA256 [LOCAL_RESTIC_REPOSITORY]\n' "$0" >&2
  exit 2
fi
capsule=$1
identity=$2
snapshot=$3
capsule_sha256=$4
repository=${5:-}
repo=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
if [ "$(id -un)" != mac ] || [ "$HOME" != /Users/mac ]; then
  printf '%s\n' 'Recovery currently targets the mac account at /Users/mac.' >&2
  exit 1
fi
case "$repo/" in /Users/mac/Developer/*)
  printf '%s\n' 'Bootstrap outside /Users/mac/Developer; restore refuses existing target trees.' >&2
  exit 1
  ;;
esac
if [ -e /Users/mac/Developer ]; then
  printf '%s\n' 'Developer already exists. For an interrupted recovery, resume with the installed recovery:restore command and the same session.' >&2
  exit 1
fi
if ! xcode-select -p >/dev/null 2>&1; then
  printf '%s\n' 'Install Command Line Tools with xcode-select --install, then rerun recovery.' >&2
  exit 1
fi
[ -f "$capsule" ] && [ -f "$identity" ] || {
  echo 'Capsule or identity missing.' >&2
  exit 1
}
work=$(mktemp -d /private/tmp/mac-recovery.XXXXXX)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mise=$HOME/.local/bin/mise
if [ ! -x "$mise" ]; then
  curl -fsSL https://mise.run -o "$work/mise-installer"
  MISE_VERSION=v2026.11.2 sh "$work/mise-installer"
fi
"$mise" -C "$repo" trust
"$mise" -C "$repo" install
"$mise" -C "$repo" exec -- python3 -I "$repo/services/backup/open_capsule.py" \
  "$capsule" --identity "$identity" --destination "$work/opened" \
  --age "$("$mise" -C "$repo" which age)" --sha256 "$capsule_sha256"
opened=$work/opened/capsule
"$mise" -C "$repo" exec -- python3 -I -c \
  'import json,sys; m=json.load(open(sys.argv[1])); assert m["snapshot"] == sys.argv[2], "Capsule/snapshot mismatch"' \
  "$opened/metadata.json" "$snapshot"
"$mise" -C "$repo" exec -- age -d -i "$identity" -o "$work/config.toml" "$opened/config.toml.age"
/bin/sh "$repo/.mise/tasks/accounts/install"
if sudo test -L /etc/fnox || sudo test -L /etc/fnox/operational.key || sudo test -L /etc/fnox/restic-password.age; then
  echo 'Refusing symlinked secret paths.' >&2
  exit 1
fi
sudo install -d -o root -g wheel -m 700 /etc/fnox
for name in operational.key restic-password.age; do
  case "$name" in
  operational.key) source=$identity ;;
  restic-password.age) source=$opened/restic-password.age ;;
  esac
  if sudo test -e "/etc/fnox/$name"; then
    sudo cmp -s "$source" "/etc/fnox/$name" || {
      printf 'Existing %s differs; refusing to replace recovery credentials.\n' "$name" >&2
      exit 1
    }
  else
    sudo install -o root -g wheel -m 600 "$source" "/etc/fnox/$name"
  fi
done
# Stage never registers/starts a server, so no service can initialize empty data.
/bin/sh "$repo/services/security/deploy.sh" stage "$work/config.toml"
set -- "$snapshot"
if [ -n "$repository" ]; then
  set -- "$@" --repository "$repository"
fi
sudo /usr/local/libexec/mac-server/backup/launch.sh verify "$@"
sudo /usr/local/libexec/mac-server/backup/launch.sh restore "$@" --session reinstall-1 --offline
printf '%s\n' 'Recovery installed and verified all targets. Services remain stopped.' \
  'Inspect recovered data, then run: sh /Users/mac/Developer/configuration/setup.sh' \
  'If an escrow identity was used, rotate to a dedicated operational identity after acceptance.'
