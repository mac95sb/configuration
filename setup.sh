#!/bin/sh

set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  printf '%s\n' 'This setup script requires macOS.' >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || :
  printf '%s\n' 'Waiting for Xcode Command Line Tools to finish installing...'
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
fi

ssh_key=$HOME/.ssh/id_ed25519
if [ ! -f "$ssh_key" ]; then
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C 'contact@maclong.dev' -f "$ssh_key"
fi

dotfiles=$HOME/Developer/configuration

if [ -d "$dotfiles/.git" ]; then
  printf '%s\n' "Dotfiles already cloned at $dotfiles"
else
  mkdir -p "$(dirname "$dotfiles")"
  git clone https://github.com/mac95sb/configuration "$dotfiles"
fi

mise=$HOME/.local/bin/mise
if [ ! -x "$mise" ]; then
  curl -fsSL https://mise.run | sh
fi

"$mise" -C "$dotfiles" trust
"$mise" -C "$dotfiles" install
"$mise" -C "$dotfiles" run skills
"$mise" -C "$dotfiles" exec -- mise bootstrap --yes --force-dotfiles

sudo_file=/etc/pam.d/sudo_local
sudo_template=/etc/pam.d/sudo_local.template

if [ ! -f "$sudo_template" ]; then
  printf '%s\n' "Touch ID for sudo is unsupported: $sudo_template does not exist." >&2
  exit 1
fi

sudo cp "$sudo_template" "$sudo_file"
sudo sed -i '' 's/^#auth/auth/' "$sudo_file"
