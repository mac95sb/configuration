# Configuration

Mac's dotfiles. Homebrew for packages, symlinked dotfiles for config.

## Setup

```sh
mkdir -p ~/Developer
git clone https://github.com/maclong9/configuration ~/Developer/configuration
cd ~/Developer/configuration
./scripts/install
```

`scripts/install` installs Homebrew (if missing), runs `brew bundle`, symlinks all dotfiles, and applies macOS system defaults (requires sudo for firewall and Touch ID).

## SSH key

```sh
ssh-keygen -t ed25519 -C "contact@maclong.dev"
gh auth login
```

## Shell helpers

| Command     | Action                           |
| ----------- | -------------------------------- |
| `kp <port>` | Kill the process on a port.      |
