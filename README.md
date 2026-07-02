# Configuration

## Setup

```sh
DOTFILES="$HOME/Developer/configuration"
mkdir -p "$(dirname "$DOTFILES")"
git clone https://github.com/mac95sb/configuration "$DOTFILES"
curl https://mise.run | sh
"$HOME/.local/bin/mise" -C "$DOTFILES" trust
"$HOME/.local/bin/mise" -C "$DOTFILES" bootstrap --yes --force-dotfiles
```

## SSH key

```sh
ssh-keygen -t ed25519 -C "contact@maclong.dev"
gh auth login
```
