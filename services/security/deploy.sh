#!/bin/sh
# Explicit administrative boundary: review this checkout and all selected inputs first.
set -eu
usage() {
  echo 'Usage: deploy.sh {deploy|stage} [reviewed_fnox_config_path] | {tools|config}' >&2
  exit 64
}
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
action=$1
case "$action" in
deploy | stage) ;;
tools | config) [ "$#" = 1 ] || usage ;;
*) usage ;;
esac
# This checkout is a trusted input only during explicit administrative deployment.
repo=$(CDPATH='' cd -- "$(/usr/bin/dirname "$0")/../.." && pwd -P)
reviewed_config=${2-"$repo/fnox.toml"}
if [ "$action" = deploy ] || [ "$action" = stage ]; then
  [ -n "$reviewed_config" ] || usage
  case "$reviewed_config" in
  /*) ;;
  *) reviewed_config="$(pwd -P)/$reviewed_config" ;;
  esac
  # The source may be root-only recovery material. Validate/read it only in the
  # elevated installer, not with an unprivileged test of its private parent path.
fi
# Resolve mise tools using this checkout, not the caller's unrelated directory.
cd "$repo"
set -- "$action"
if [ "$action" != config ]; then
  # Tool discovery belongs only to this explicit deployment, never root startup.
  # Fresh shells need not have sourced mise's PATH activation.
  mise_bin=${HOME:?HOME must be set}/.local/bin/mise
  if [ ! -e "$mise_bin" ] && [ ! -L "$mise_bin" ]; then
    mise_bin=$(command -v mise) || {
      echo 'Install mise in ~/.local/bin/mise or PATH first.' >&2
      exit 1
    }
  fi
  [ -f "$mise_bin" ] && [ -x "$mise_bin" ] || {
    echo "Mise is not an executable file: $mise_bin" >&2
    exit 1
  }
  # `mise where` also finds the installed Python while the coordinator adds its pin.
  python_prefix=$("$mise_bin" where python)
  [ -x "$python_prefix/bin/python3" ] || {
    echo 'Install a standalone mise Python >=3.11 first.' >&2
    exit 1
  }
  set -- "$@" --tool "python3=$python_prefix/bin/python3"
  for name in age alloy blackbox_exporter caddy cloudflared fnox loki node_exporter pitchfork prometheus rclone restic; do
    path=$("$mise_bin" which "$name") || {
      echo "Install/pin $name with mise before deployment." >&2
      exit 1
    }
    set -- "$@" --tool "$name=$path"
  done
fi
if [ "$action" = deploy ] || [ "$action" = stage ]; then
  set -- "$@" --config "$reviewed_config"
fi
# The bootstrap interpreter is the OS Python, not a user import environment.
# User-controlled inputs are trusted ONLY by choosing to run this explicit deployment.
exec /usr/bin/sudo /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME=/var/root \
  /usr/bin/python3 -I -S "$repo/services/security/install.py" "$@"
