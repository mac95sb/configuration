#!/bin/sh
set -eu
umask 077

case $#:${1:-} in
0:) setup_args= ;;
1:--recover) setup_args=--recover ;;
*)
  printf 'Usage: %s [--recover]\n' "$0" >&2
  exit 2
  ;;
esac

if [ ! -t 0 ]; then
  printf '%s\n' 'Setup needs a terminal for the age key and first-run prompts.' >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  printf '\n==> Installing Xcode Command Line Tools\n'
  xcode-select --install || :
  printf '%s\n' 'Waiting for Xcode Command Line Tools to finish installing'
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
fi

repo=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
mise=$HOME/.local/bin/mise
if [ ! -x "$mise" ]; then
  installer=$(mktemp "${TMPDIR:-/tmp}/mise-installer.XXXXXX")
  trap 'rm -f "$installer"' 0
  curl -fsSL https://mise.run -o "$installer"
  MISE_VERSION=v2026.11.2 sh "$installer"
  rm -f "$installer"
  trap - 0
fi

"$mise" -C "$repo" trust
MISE_SETUP_IN_PROGRESS=1 "$mise" -C "$repo" install
if [ -n "$setup_args" ]; then
  "$mise" -C "$repo" run setup "$setup_args"
else
  "$mise" -C "$repo" run setup
fi
