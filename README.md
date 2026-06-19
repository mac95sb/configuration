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

## Config rebuild

After pulling changes, `cr` in the shell re-runs `scripts/install`.

## SSH key

```sh
ssh-keygen -t ed25519 -C "contact@maclong.dev"
gh auth login --hostname github.com --git-protocol ssh --scopes "repo,read:org,gist"
gh ssh-key add ~/.ssh/id_ed25519.pub --type authentication
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing
```

## Shell helpers

| Command     | Action                           |
| ----------- | -------------------------------- |
| `kp <port>` | Kill the process on a port.      |
