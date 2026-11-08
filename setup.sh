#!/bin/sh

set -eu
umask 077
new_system=false
case ${1:-} in
--new) new_system=true ;;
'') ;;
*)
  printf 'Usage: %s [--new]\n' "$0" >&2
  exit 2
  ;;
esac

say() {
  say_wait=false
  if [ "${1:-}" = "--wait" ]; then
    say_wait=true
    shift
  fi

  printf '\n==> %s\n' "$1"
  shift
  for say_line; do
    printf '    %s\n' "$say_line"
  done

  if [ "$say_wait" = true ]; then
    printf '%s' '    Press enter to continue... '
    read -r _
  fi
}

if [ ! -t 0 ]; then
  printf '%s\n' 'This interactive installer needs a terminal on standard input.' >&2
  printf '%s\n' 'Run it with: sh ~/Developer/configuration/setup.sh' >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  say 'Installing Xcode Command Line Tools'
  xcode-select --install || :
  say 'Waiting for Xcode Command Line Tools to finish installing'
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
fi

dotfiles=$HOME/Developer/configuration

mise=$HOME/.local/bin/mise
if [ ! -x "$mise" ]; then
  say 'Installing mise'
  installer=$(mktemp "${TMPDIR:-/tmp}/mise-installer.XXXXXX")
  curl -fsSL https://mise.run -o "$installer"
  MISE_VERSION=v2026.11.2 sh "$installer"
  rm -f "$installer"
fi

say 'Installing tools, packages, and dotfiles'
"$mise" -C "$dotfiles" trust
"$mise" -C "$dotfiles" install
"$mise" -C "$dotfiles" exec -- hk install --global --mise
"$mise" -C "$dotfiles" exec -- mise bootstrap --yes --force-dotfiles --skip repos
"$mise" -C "$dotfiles" run updates:pin

say 'Applying macOS preferences'
sudo_file=/etc/pam.d/sudo_local
sudo_template=/etc/pam.d/sudo_local.template

if [ ! -f "$sudo_template" ]; then
  printf '%s\n' "Touch ID for sudo is unsupported: $sudo_template does not exist." >&2
  exit 1
fi

if ! sudo test -f "$sudo_file"; then
  sudo cp "$sudo_template" "$sudo_file"
  sudo sed -i '' 's/^#auth/auth/' "$sudo_file"
fi

defaults write com.apple.dock persistent-apps -array

dock_apps='
/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app/
/System/Applications/Messages.app/
/System/Applications/Mail.app/
/System/Applications/Calendar.app/
/System/Applications/Reminders.app/
/System/Applications/Notes.app/
/System/Applications/Books.app/
/System/Applications/Music.app/
'
set --
for app_path in $dock_apps; do
  set -- "$@" \
    "{ \"tile-data\" = { \"file-data\" = { \"_CFURLString\" = \"file://$app_path\"; \"_CFURLStringType\" = 15; }; }; \"tile-type\" = \"file-tile\"; }"
done
defaults write com.apple.dock persistent-apps -array-add "$@"
killall Dock || :

say 'Creating service accounts and access groups'
"$mise" -C "$dotfiles" run accounts:install

say 'Configuring local outbound mail'
"$mise" -C "$dotfiles" run mail:install

say 'Installing the operational age key'
installed_key=/etc/fnox/operational.key
staged_key=$HOME/operational.key
temporary_key=

if sudo test -L /etc/fnox || sudo test -L "$installed_key"; then
  printf '%s\n' 'Refusing symlinked fnox key paths.' >&2
  exit 1
fi
if sudo test -f "$installed_key"; then
  say "Using the existing operational key at $installed_key"
else
  if [ ! -f "$staged_key" ]; then
    say 'Operational age key required' \
      'Paste the matching AGE-SECRET-KEY value below; input is hidden.' \
      'Its public recipient must already be present in fnox.toml.'
    temporary_key=$(mktemp "${TMPDIR:-/tmp}/operational-key.XXXXXX")
    chmod 600 "$temporary_key"
    staged_key=$temporary_key
    trap 'stty echo 2>/dev/null || :; rm -f "$temporary_key"' EXIT
    trap 'exit 1' HUP INT TERM
    printf '%s' '    Key: '
    stty -echo
    if ! IFS= read -r operational_identity; then
      exit 1
    fi
    stty echo
    printf '\n'
    printf '%s\n' "$operational_identity" >"$staged_key"
    unset operational_identity
  fi

  if [ ! -f "$staged_key" ]; then
    printf '%s\n' "No key found at $staged_key." >&2
    exit 1
  fi

  operational_recipient=$("$mise" -C "$dotfiles" exec -- age-keygen -y "$staged_key")
  if ! grep -Fq "\"$operational_recipient\"" "$dotfiles/fnox.toml"; then
    printf '%s\n' \
      "The staged key's recipient ($operational_recipient) is not in fnox.toml." \
      'Re-encrypt the fnox secrets for this recipient before continuing.' >&2
    exit 1
  fi

  sudo install -d -m 700 -o root -g wheel /etc/fnox
  sudo install -o root -g wheel -m 600 "$staged_key" "$installed_key"
  rm -f "$staged_key"
fi

if [ -n "$temporary_key" ]; then
  rm -f "$temporary_key"
  trap - EXIT HUP INT TERM
fi

sudo chown root:wheel /etc/fnox "$installed_key"
sudo chmod 700 /etc/fnox
sudo chmod 600 "$installed_key"

forgejo_db=/Users/svc_forgejo/forgejo-data/data/forgejo.db
grafana_db=/Users/svc_observability/grafana-data/grafana.db
if [ "$new_system" = false ] &&
  { ! sudo test -f "$forgejo_db" || ! sudo test -f "$grafana_db"; }; then
  printf '%s\n' 'Service state is missing. Restore first using recover.sh from a temporary checkout outside Developer.' \
    'Use setup.sh --new only to create genuinely new, empty services.' >&2
  exit 1
fi
if [ "$new_system" = true ] &&
  { sudo test -e "$forgejo_db" || sudo test -e "$grafana_db"; }; then
  printf '%s\n' '--new refuses existing service databases; use ordinary setup after a complete restore.' >&2
  exit 1
fi

say 'Deploying reviewed protected service runtime (services not restarted yet)'
if sudo test -f /etc/fnox/config.toml; then
  # A recovered/deployed config can contain credentials newer than Git's copy.
  /bin/sh "$dotfiles/services/security/deploy.sh" deploy /etc/fnox/config.toml
else
  "$mise" -C "$dotfiles" run daemon:install
fi
sudo chmod o+x /Users/mac

say 'Configuring the Cloudflare Tunnel'
cloudflared_config=$dotfiles/services/cloudflared/config.yml
tunnel_id=$(awk '/^tunnel:/ { print $2; exit }' "$cloudflared_config")
encrypted_credentials=$dotfiles/services/cloudflared/credentials.json.age
installed_credentials=/etc/cloudflared/$tunnel_id.json

if [ ! -f "$installed_credentials" ]; then
  if [ ! -f "$encrypted_credentials" ]; then
    printf 'Encrypted credentials for tunnel %s are missing.\n' "$tunnel_id" >&2
    exit 1
  fi

  credential_tmp_dir=$(mktemp -d /private/tmp/cloudflared-credential.XXXXXX)
  credential_tmp=$credential_tmp_dir/credential.json
  sudo chown root:wheel "$credential_tmp_dir"
  sudo chmod 700 "$credential_tmp_dir"
  trap 'sudo rm -rf "$credential_tmp_dir"' EXIT
  trap 'exit 1' HUP INT TERM
  sudo /usr/local/bin/age -d -i /etc/fnox/operational.key \
    -o "$credential_tmp" "$encrypted_credentials"
  restored_tunnel_id=$(sudo /usr/bin/plutil \
    -extract TunnelID raw -o - "$credential_tmp")
  if [ "$restored_tunnel_id" != "$tunnel_id" ]; then
    printf 'Encrypted credentials do not belong to tunnel %s.\n' "$tunnel_id" >&2
    exit 1
  fi
  sudo install -d -m 755 -o root -g wheel /etc/cloudflared
  sudo install -o svc_cloudflared -g staff -m 400 \
    "$credential_tmp" "$installed_credentials"
  sudo rm -rf "$credential_tmp_dir"
  trap - EXIT HUP INT TERM
fi

say 'Reusing the existing Cloudflare tunnel, DNS routes, and Access policy'

say 'Enabling server power settings'
"$mise" -C "$dotfiles" run host:server

say 'Activating the protected root Pitchfork supervisor'
"$mise" -C "$dotfiles" run daemon:activate

say 'Creating the first Forgejo administrator, if needed'
forgejo_work_path=/Users/svc_forgejo/forgejo-data
forgejo_config=$forgejo_work_path/app.ini

attempt=0
while [ ! -f "$forgejo_config" ] && [ "$attempt" -lt 15 ]; do
  sleep 2
  attempt=$((attempt + 1))
done

if ! users=$(sudo -u svc_forgejo /usr/local/bin/forgejo admin user list \
  --work-path "$forgejo_work_path" --config "$forgejo_config"); then
  printf '%s\n' 'Could not list Forgejo users; refusing to treat a service error as an empty database.' >&2
  exit 1
fi
if printf '%s\n' "$users" | grep -Eq '^[[:space:]]*[0-9]+[[:space:]]+'; then
  say 'A Forgejo user already exists; skipping administrator creation'
else
  say 'Choose the initial Forgejo administrator'
  printf '%s' 'Username: '
  read -r forgejo_username
  printf '%s' 'Email: '
  read -r forgejo_email

  # Forgejo generates and prints the password. Passing one as --password would
  # expose it in `ps` to every local account for the life of the command.
  sudo -u svc_forgejo /usr/local/bin/forgejo admin user create \
    --work-path "$forgejo_work_path" \
    --config "$forgejo_config" \
    --username "$forgejo_username" \
    --email "$forgejo_email" \
    --random-password \
    --must-change-password \
    --admin
  say --wait 'Save the generated password above' \
    'Forgejo requires changing it at first login.'
fi

unset users

say 'Preparing Git authentication and signing'
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -C contact@maclong.dev
  cat "$HOME/.ssh/id_ed25519.pub"
  say --wait 'Register the public key above with your Forgejo user (authentication and signing)' \
    'Keep private-key recovery separate; it is not included in a public configuration bundle.'
fi

say 'Pointing configuration and robin at Forgejo'
/bin/sh "$dotfiles/services/git/forgejo.sh"
if [ "$new_system" = true ]; then
  say --wait 'Create empty mac/configuration and mac/robin repositories in Forgejo'
fi
for name in configuration robin; do
  checkout=$HOME/Developer/$name
  GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10' git -C "$checkout" ls-remote origin HEAD
  if [ "$new_system" = true ]; then
    git -C "$checkout" push origin --all
    git -C "$checkout" push origin --tags
  fi
done

say 'Opening the Restic repository without replacing an existing password'
"$mise" -C "$dotfiles" run recovery:init
say 'System provisioning complete' \
  'Commit reviewed configuration changes, then run mise run recovery:checkpoint.' \
  'Before erasing: verify the exact snapshot from an independent downloaded copy.'
