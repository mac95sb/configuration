#!/bin/sh

set -eu

if [ "$(uname -s)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then
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

printf '%s\n' "Add this SSH key to https://github.com/settings/ssh/new:"
cat "$ssh_key.pub"
until printf '%s' "Press enter once the key has been added..." && read -r _ && ssh -T git@github.com; do
	printf '%s\n' "SSH check against github.com failed, please try again."
done

dotfiles=$HOME/Developer/configuration

if [ -d "$dotfiles/.git" ]; then
	printf '%s\n' "Dotfiles already cloned at $dotfiles"
else
	mkdir -p "$(dirname "$dotfiles")"
	git clone git@github.com:mac95sb/configuration.git "$dotfiles"
fi

mise=$HOME/.local/bin/mise
if [ ! -x "$mise" ]; then
	curl -fsSL https://mise.run | sh
fi

"$mise" -C "$dotfiles" trust
"$mise" -C "$dotfiles" install
"$mise" -C "$dotfiles" exec -- mise bootstrap --yes --force-dotfiles

if [ "$(uname -s)" = "Darwin" ]; then
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
fi
