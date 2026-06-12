#!/bin/sh
set -eu

# Install Xcode CLI Tools if missing
if ! xcode-select -p >/dev/null 2>&1; then
	xcode-select --install
	echo "Waiting for Xcode Command Line Tools..."
	until xcode-select -p >/dev/null 2>&1; do
		sleep 5
	done
fi

# Generate SSH key if one doesn't exist
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
	ssh-keygen -t ed25519 -C "$(hostname)" -f "$HOME/.ssh/id_ed25519" -N ""
fi
pbcopy < "$HOME/.ssh/id_ed25519.pub"
printf "✓ SSH public key copied to clipboard.\n"
printf "  → Add it at: https://github.com/settings/ssh/new\n\n"
printf "Press Enter once you've added the key to GitHub..."
read _

# Clone configuration and link dotfiles
[ -d "$HOME/.config" ] && mv "$HOME/.config" "$HOME/.config.bak.$(date +%Y%m%d_%H%M%S)"
git clone git@github.com:mac95sb/configuration "$HOME/.config"
for f in "$HOME"/.config/.[!.]*; do
	base=$(basename "$f")
	[ "$base" = ".git" ] && continue
	[ -e "$HOME/$base" ] && ! [ -L "$HOME/$base" ] && continue
	ln -sf "$f" "$HOME/$base"
done

# Install Homebrew if missing
if ! command -v brew >/dev/null 2>&1; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true

# Install packages
brew bundle --file "$HOME/.config/Brewfile"

# Enable Touch ID for sudo
if ! grep -q '^auth.*pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null; then
	sudo sed 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local > /dev/null
fi

# Install Neovim plugins and start container system in parallel
printf 'a\n' | nvim --headless 2>/dev/null &
container system start --enable-kernel-install &
wait

printf "\nInstallation complete. Enjoy!\n"
printf "  → Open Neovim and run :Mason to install language servers.\n"
