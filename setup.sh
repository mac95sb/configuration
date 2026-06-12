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

# Clone and link configuration files
CONFIG_TMP=$(mktemp -d "$HOME/.config.tmp.XXXXXX")
trap '[ -n "${CONFIG_TMP:-}" ] && rm -rf "$CONFIG_TMP"' EXIT
git clone git@github.com:mac95sb/configuration "$CONFIG_TMP"
if [ -d "$HOME/.config" ]; then
	mv "$HOME/.config" "$HOME/.config.bak.$(date +%Y%m%d_%H%M%S)"
fi
mv "$CONFIG_TMP" "$HOME/.config"
CONFIG_TMP=
for f in "$HOME"/.config/.[!.]*; do
	[ -e "$f" ] || continue
	[ "$(basename "$f")" = ".git" ] && continue
	target="$HOME/$(basename "$f")"
	if [ -e "$target" ] || [ -L "$target" ]; then
		printf "Skipping %s; target already exists.\n" "$target"
		continue
	fi
	ln -s "$f" "$target"
done

# Install Nerd Font (Liga SF Mono)
FONT_DIR="$HOME/Library/Fonts"
mkdir -p "$FONT_DIR"
curl -fsSL "https://github.com/shaunsingh/SFMono-Nerd-Font-Ligaturized/raw/refs/heads/main/LigaSFMonoNerdFont-Regular.otf" \
	-o "$FONT_DIR/LigaSFMonoNerdFont-Regular.otf"
printf "✓ LigaSFMonoNerdFont-Regular installed.\n"
printf "  → Set it as your terminal font to enable Neovim icons.\n\n"

# Install dependencies
zsh -c "source ~/.zshrc && ghi neovim/neovim tmux/tmux-builds apple/container"
zsh -c "source ~/.zshrc && nvim_deps"
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh

# Set up dev container
container system start --enable-kernel-install
zsh -c "source ~/.zshrc && dev_build"
if ! container machine inspect dev >/dev/null 2>&1; then
	container machine create --name dev --set-default local/dev-void:latest
else
	container machine set-default dev
fi

printf "\nInstallation complete. Enjoy!\n"
