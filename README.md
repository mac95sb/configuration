# POSIX fallback

This branch is auto-generated from the Nix-managed macOS configuration for
machines where Nix is unavailable.

## Quick Start

```sh
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Clone and switch to this branch
mkdir -p ~/Developer
git clone -b posix https://github.com/mac95sb/configuration ~/Developer/configuration
cd ~/Developer/configuration

# Install packages
brew bundle

# Symlink dotfiles
mkdir -p ~/.config/ghostty ~/.config/tmux ~/.config/git ~/.config/gh
ln -sf ~/Developer/configuration/.zshrc ~/.zshrc
ln -sf ~/Developer/configuration/.config/ghostty/config ~/.config/ghostty/config
ln -sf ~/Developer/configuration/.config/tmux/tmux.conf ~/.config/tmux/tmux.conf
ln -sf ~/Developer/configuration/.config/git/config ~/.config/git/config
ln -sf ~/Developer/configuration/.config/git/allowed_signers ~/.config/git/allowed_signers
ln -sf ~/Developer/configuration/.config/git/ignore ~/.config/git/ignore
ln -sf ~/Developer/configuration/.config/gh/config.yml ~/.config/gh/config.yml

# SSH key
ssh-keygen -t ed25519 -C "contact@maclong.dev"
gh auth login --hostname github.com --git-protocol ssh --scopes "repo,read:org,gist"
gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --type authentication
gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --type signing
```
