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
  printf '%s\n' "Run it with: /bin/sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/mac95sb/configuration/main/setup.sh)\"" >&2
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

ssh_key=$HOME/.ssh/id_ed25519
if [ ! -f "$ssh_key" ]; then
  say 'Generating the GitHub SSH key'
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C 'contact@maclong.dev' -f "$ssh_key"
fi

say 'Add this SSH key to GitHub' 'https://github.com/settings/ssh/new'
cat "$ssh_key.pub"
while :; do
  say --wait 'Continue after adding the GitHub SSH key'
  github_auth=$(ssh -T git@github.com 2>&1 || :)
  if printf '%s\n' "$github_auth" | grep -q 'successfully authenticated'; then
    break
  fi
  printf '%s\n' "$github_auth" >&2
  say 'GitHub SSH authentication failed; try again'
done

dotfiles=$HOME/Developer/configuration

if [ -d "$dotfiles/.git" ]; then
  say "Configuration repository already cloned at $dotfiles"
else
  say "Cloning the configuration repository into $dotfiles"
  mkdir -p "$(dirname "$dotfiles")"
  git clone git@github.com:mac95sb/configuration.git "$dotfiles"
fi

mise=$HOME/.local/bin/mise
if [ ! -x "$mise" ]; then
  say 'Installing mise'
  curl -fsSL https://mise.run | sh
fi

say 'Installing tools, packages, dotfiles, and repositories'
"$mise" -C "$dotfiles" trust
"$mise" -C "$dotfiles" install
"$mise" -C "$dotfiles" exec -- mise bootstrap --yes --force-dotfiles

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

say 'Installing the operational age key'
installed_key=/etc/fnox/operational.key
staged_key=$HOME/operational.key

if [ -f "$installed_key" ]; then
  say "Using the existing operational key at $installed_key"
else
  if [ ! -f "$staged_key" ]; then
    say --wait 'Operational age key required' \
      "Place the matching private key at $staged_key." \
      'The public recipient derived from it must already be present in fnox.toml.' \
      'For disaster recovery, retrieve the escrow key from Apple Passwords, decrypt the secrets, and rotate them to a new operational recipient; do not generate an unrelated key for existing ciphertext.'
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

say 'Configuring the Cloudflare Tunnel'
cloudflared_config=$dotfiles/services/cloudflared/config.yml
tunnel_id=$(awk '/^tunnel:/ { print $2; exit }' "$cloudflared_config")
cloudflared_home=$HOME/.cloudflared
local_credentials=$cloudflared_home/$tunnel_id.json

if [ ! -f "$local_credentials" ]; then
  say --wait 'Cloudflare browser authentication required' \
    'On a rebuild, delete or rename the old home-caddy tunnel in the dashboard first; locally-managed tunnel credentials cannot be regenerated.'
  "$mise" -C "$dotfiles" exec -- cloudflared tunnel login

  create_output=''
  until create_output=$("$mise" -C "$dotfiles" exec -- cloudflared tunnel create home-caddy 2>&1); do
    printf '%s\n' "$create_output" >&2
    say --wait 'Resolve the home-caddy tunnel-name conflict in Cloudflare before retrying'
  done
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
fi

sudo install -d -m 755 -o root -g wheel /etc/cloudflared
sudo install -o svc_cloudflared -g staff -m 400 \
  "$local_credentials" "/etc/cloudflared/$tunnel_id.json"

say --wait 'Protect dashboard.maclong.dev with Cloudflare Access' \
  'In Cloudflare Zero Trust, create a self-hosted Access application for dashboard.maclong.dev.' \
  'Add an Allow policy restricted to your identity before continuing.'

awk '$1 == "-" && $2 == "hostname:" { print $3 }' "$cloudflared_config" |
  while IFS= read -r hostname; do
    "$mise" -C "$dotfiles" exec -- \
      cloudflared tunnel route dns --overwrite-dns "$tunnel_id" "$hostname"
  done

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
  say 'Choose the initial Forgejo administrator credentials'
  printf '%s' 'Username: '
  read -r forgejo_username
  printf '%s' 'Email: '
  read -r forgejo_email
  printf '%s' 'Temporary password (input hidden): '
  trap 'stty echo 2>/dev/null || :' EXIT HUP INT TERM
  stty -echo
  read -r forgejo_password
  stty echo
  trap - EXIT HUP INT TERM
  printf '\n'
  sudo -u svc_forgejo /usr/local/bin/forgejo admin user create \
    --work-path "$forgejo_work_path" \
    --config "$forgejo_config" \
    --username "$forgejo_username" \
    --email "$forgejo_email" \
    --password "$forgejo_password" \
    --admin
  unset forgejo_password
fi

say 'Configuring Forgejo-primary repositories and GitHub mirrors'
for repo_name in configuration robin; do
  repository=$HOME/Developer/$repo_name
  forgejo_url=https://git.maclong.dev/mac/$repo_name.git
  github_url=https://github.com/mac95sb/$repo_name.git

  if [ ! -d "$repository/.git" ]; then
    say "Skipping $repo_name because $repository is not cloned"
    continue
  fi

  current_origin=$(git -C "$repository" remote get-url origin 2>/dev/null || :)
  current_github=$(git -C "$repository" remote get-url github 2>/dev/null || :)
  if [ "$current_origin" = "$forgejo_url" ] && [ "$current_github" = "$github_url" ]; then
    say "$repo_name already uses Forgejo as origin and GitHub as its mirror remote"
    continue
  fi

  say --wait "Prepare the $repo_name repository mirrors" \
    "1. Create the empty mac/$repo_name repository in Forgejo." \
    "2. Add its GitHub push mirror for $github_url with the scoped PAT."

  if git -C "$repository" remote get-url forgejo >/dev/null 2>&1; then
    git -C "$repository" remote set-url forgejo "$forgejo_url"
  else
    git -C "$repository" remote add forgejo "$forgejo_url"
  fi
  git -C "$repository" push forgejo --all
  git -C "$repository" push forgejo --tags

  if git -C "$repository" remote get-url github >/dev/null 2>&1; then
    git -C "$repository" remote set-url github "$github_url"
    git -C "$repository" remote set-url origin "$forgejo_url"
    git -C "$repository" remote remove forgejo
  else
    git -C "$repository" remote rename origin github
    git -C "$repository" remote set-url github "$github_url"
    git -C "$repository" remote rename forgejo origin
  fi
done

say 'System provisioning complete'
