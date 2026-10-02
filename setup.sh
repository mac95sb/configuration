#!/bin/sh

set -eu

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
  curl -fsSL https://mise.run | sh
fi

say 'Installing tools, packages, and dotfiles'
"$mise" -C "$dotfiles" trust
"$mise" -C "$dotfiles" install
"$mise" -C "$dotfiles" exec -- mise bootstrap --yes --force-dotfiles --skip repos

say 'Applying macOS preferences'
sudo_file=/etc/pam.d/sudo_local
sudo_template=/etc/pam.d/sudo_local.template

if [ ! -f "$sudo_template" ]; then
  printf '%s\n' "Touch ID for sudo is unsupported: $sudo_template does not exist." >&2
  exit 1
fi

sudo cp "$sudo_template" "$sudo_file"
sudo sed -i '' 's/^#auth/auth/' "$sudo_file"

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

if [ -f "$installed_key" ]; then
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

  sudo install -d -m 750 -o root -g fnox /etc/fnox
  sudo install -o root -g fnox -m 440 "$staged_key" "$installed_key"
  rm -f "$staged_key"
fi

if [ -n "$temporary_key" ]; then
  rm -f "$temporary_key"
  trap - EXIT HUP INT TERM
fi

say 'Preparing service binaries for restoration'
"$mise" -C "$dotfiles" run daemon:relink
sudo chmod o+x /Users/mac

forgejo_db=/Users/svc_forgejo/forgejo-data/data/forgejo.db
grafana_db=/Users/svc_observability/grafana-data/grafana.db
restored=false
if [ ! -e "$forgejo_db" ] && [ ! -e "$grafana_db" ]; then
  say 'Restoring the latest service state'
  "$dotfiles/services/backup/restore.sh"
  restored=true
elif [ ! -e "$forgejo_db" ] || [ ! -e "$grafana_db" ]; then
  printf '%s\n' 'Only one service database exists; refusing to mix live and restored state.' >&2
  exit 1
fi

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
  sudo chown svc_backup:staff "$credential_tmp_dir"
  sudo chmod 700 "$credential_tmp_dir"
  trap 'sudo -u svc_backup rm -rf "$credential_tmp_dir"' EXIT
  trap 'exit 1' HUP INT TERM
  sudo -u svc_backup /usr/local/bin/age -d -i /etc/fnox/operational.key \
    -o "$credential_tmp" "$encrypted_credentials"
  restored_tunnel_id=$(sudo -u svc_backup /usr/bin/plutil \
    -extract TunnelID raw -o - "$credential_tmp")
  if [ "$restored_tunnel_id" != "$tunnel_id" ]; then
    printf 'Encrypted credentials do not belong to tunnel %s.\n' "$tunnel_id" >&2
    exit 1
  fi
  sudo install -d -m 755 -o root -g wheel /etc/cloudflared
  sudo install -o svc_cloudflared -g staff -m 400 \
    "$credential_tmp" "$installed_credentials"
  sudo -u svc_backup rm -rf "$credential_tmp_dir"
  trap - EXIT HUP INT TERM
fi

say 'Reusing the existing Cloudflare tunnel, DNS routes, and Access policy'

say 'Installing and starting the pitchfork supervisor'
"$mise" -C "$dotfiles" run daemon:install
"$mise" -C "$dotfiles" run daemon:reload

say 'Creating the first Forgejo administrator, if needed'
forgejo_work_path=/Users/svc_forgejo/forgejo-data
forgejo_config=$forgejo_work_path/app.ini

attempt=0
while [ ! -f "$forgejo_config" ] && [ "$attempt" -lt 15 ]; do
  sleep 2
  attempt=$((attempt + 1))
done

if sudo -u svc_forgejo /usr/local/bin/forgejo admin user list \
  --work-path "$forgejo_work_path" --config "$forgejo_config" 2>/dev/null |
  grep -Eq '^[[:space:]]*[0-9]+[[:space:]]+'; then
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

say 'Pointing the configuration repository at Forgejo'
forgejo_url=git@git.maclong.dev:mac/configuration.git
current_origin=$(git -C "$dotfiles" config --get remote.origin.url 2>/dev/null || :)

if [ "$current_origin" = "$forgejo_url" ]; then
  say 'The configuration repository already uses Forgejo as origin'
elif [ "$restored" = true ]; then
  git -C "$dotfiles" remote set-url origin "$forgejo_url"
  say 'Restored Forgejo already contains the configuration repository'
else
  say --wait 'Create the empty mac/configuration repository in Forgejo before continuing'

  if [ -n "$current_origin" ]; then
    git -C "$dotfiles" remote set-url origin "$forgejo_url"
  else
    git -C "$dotfiles" remote add origin "$forgejo_url"
  fi

  git -C "$dotfiles" push origin --all
  git -C "$dotfiles" push origin --tags
fi

say 'System provisioning complete'
