# Configuration

## Setup

```sh
DOTFILES="$HOME/Developer/configuration"
mkdir -p "$(dirname "$DOTFILES")"
git clone https://github.com/mac95sb/configuration "$DOTFILES"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew bundle --file "$DOTFILES/Brewfile"
mise -C "$DOTFILES" trust
mise -C "$DOTFILES" bootstrap --force-dotfiles
```

## SSH key

```sh
ssh-keygen -t ed25519 -C "contact@maclong.dev"
gh auth login
```

## Shell helpers

| Command     | Action                            |
| ----------- | --------------------------------- |
| `kp <port>` | Kill the process on a port.       |
