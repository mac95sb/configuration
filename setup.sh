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
bundle_dir=$HOME/Library/Mobile\ Documents/com~apple~CloudDocs/Backups/configuration
bundle=$bundle_dir/configuration-latest.bundle
bundle_placeholder=$bundle_dir/.configuration-latest.bundle.icloud

if [ ! -d "$dotfiles/.git" ]; then
  if [ ! -f "$bundle" ] && [ ! -f "$bundle_placeholder" ]; then
    printf '%s\n' \
      "No configuration clone at $dotfiles and no bundle at $bundle." \
      'Recover the most recent bundle from iCloud Drive or Cloudflare R2 first.' >&2
    exit 1
  fi

  say 'Materialising the configuration bundle from iCloud Drive'
  brctl download "$bundle" || :

  attempt=0
  until git bundle verify "$bundle" >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 60 ]; then
      printf '%s\n' "The bundle at $bundle did not materialise." >&2
      exit 1
    fi
    sleep 5
  done

  say "Cloning the configuration repository into $dotfiles"
  mkdir -p "$(dirname "$dotfiles")"
  git clone "$bundle" "$dotfiles"
fi

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

say 'Required outbound mail DNS records'
"$mise" -C "$dotfiles" run mail:dns
say --wait 'Publish the outbound mail DNS records shown above'

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
cloudflared_home=$HOME/.cloudflared
local_credentials=$cloudflared_home/$tunnel_id.json
encrypted_credentials=$dotfiles/services/cloudflared/credentials.json.age
new_tunnel=false

if [ ! -f "/etc/cloudflared/$tunnel_id.json" ] && [ -f "$encrypted_credentials" ]; then
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
    "$credential_tmp" "/etc/cloudflared/$tunnel_id.json"
  sudo -u svc_backup rm -rf "$credential_tmp_dir"
  trap - EXIT HUP INT TERM
fi

if [ ! -f "/etc/cloudflared/$tunnel_id.json" ] && [ ! -f "$local_credentials" ]; then
  say --wait 'Cloudflare browser authentication required'
  "$mise" -C "$dotfiles" exec -- cloudflared tunnel login

  if ! create_output=$("$mise" -C "$dotfiles" exec -- cloudflared tunnel create home-caddy 2>&1); then
    printf '%s\n' "$create_output" >&2
    printf '%s\n' \
      'Could not create home-caddy. Restore its credential or remove the existing tunnel manually.' >&2
    exit 1
  fi
  printf '%s\n' "$create_output"

  new_tunnel_id=$(printf '%s\n' "$create_output" | grep -Eo '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' | tail -n 1)
  if [ -z "$new_tunnel_id" ] || [ ! -f "$cloudflared_home/$new_tunnel_id.json" ]; then
    printf '%s\n' 'Could not identify the newly-created tunnel credentials.' >&2
    exit 1
  fi

  tunnel_id=$new_tunnel_id
  local_credentials=$cloudflared_home/$tunnel_id.json
  config_tmp=$(mktemp "${TMPDIR:-/tmp}/cloudflared.XXXXXX")
  sed \
    -e "s/^tunnel:.*/tunnel: $tunnel_id/" \
    -e "s#^credentials-file:.*#credentials-file: /etc/cloudflared/$tunnel_id.json#" \
    "$cloudflared_config" >"$config_tmp"
  mv "$config_tmp" "$cloudflared_config"
  say 'Updated services/cloudflared/config.yml with the new tunnel ID' \
    'Review and commit that generated configuration change.'

  set --
  # Age recipients cannot contain whitespace.
  # shellcheck disable=SC2013
  for recipient in $(grep -Eo 'age1[a-z0-9]+' "$dotfiles/fnox.toml" | sort -u); do
    set -- "$@" -r "$recipient"
  done
  encrypted_tmp=$(mktemp "$dotfiles/services/cloudflared/.credentials.json.age.XXXXXX")
  rm -f "$encrypted_tmp"
  "$mise" -C "$dotfiles" exec -- age -a "$@" \
    -o "$encrypted_tmp" "$local_credentials"
  chmod 600 "$encrypted_tmp"
  mv "$encrypted_tmp" "$encrypted_credentials"
  say 'Encrypted the new tunnel credential into the configuration repository'
  new_tunnel=true
fi

if [ -f "$local_credentials" ]; then
  sudo install -d -m 755 -o root -g wheel /etc/cloudflared
  sudo install -o svc_cloudflared -g staff -m 400 \
    "$local_credentials" "/etc/cloudflared/$tunnel_id.json"
  rm -f "$local_credentials"
fi

# cert.pem is not the tunnel credential: it is a zone-wide origin certificate
# that can create, delete, and re-route every tunnel in the zone. Nothing after
# the DNS routes needs it, so it does not stay in the operator's home.
if [ "$new_tunnel" = true ] && [ -f "$cloudflared_home/cert.pem" ]; then
  awk '$1 == "-" && $2 == "hostname:" { print $3 }' "$cloudflared_config" |
    while IFS= read -r hostname; do
      "$mise" -C "$dotfiles" exec -- \
        cloudflared tunnel route dns --overwrite-dns "$tunnel_id" "$hostname"
    done
  rm -f "$cloudflared_home/cert.pem"
elif [ "$new_tunnel" = true ]; then
  say 'Skipping DNS routing: no Cloudflare origin certificate present' \
    'Run cloudflared tunnel login first if the hostnames need re-routing.'
fi

if [ "$new_tunnel" = true ]; then
  say --wait 'Protect dashboard.maclong.dev with Cloudflare Access' \
    'In Cloudflare Zero Trust, create a self-hosted Access application for dashboard.maclong.dev.' \
    'Add an Allow policy restricted to your identity before continuing.'
else
  say 'Reusing the existing Cloudflare tunnel, DNS routes, and Access policy'
fi

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
