# Configuration

## Setup

```sh
mkdir -p ~/Developer
git clone https://github.com/maclong9/configuration ~/Developer/configuration
cd ~/Developer/configuration
curl https://mise.run | sh
"$HOME/.local/bin/mise" trust
"$HOME/.local/bin/mise" bootstrap --force-dotfiles
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
