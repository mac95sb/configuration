# Configuration

Mac's system configuration. This repo is the source of truth for macOS defaults,
packages, Homebrew apps, and user dotfiles managed through nix-darwin,
home-manager, nvf, nix-homebrew, and den.

## Quick Start

Install Lix:

```sh
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

Clone the configuration:

```sh
mkdir -p ~/Developer
git clone https://github.com/mac95sb/configuration ~/Developer/configuration
cd ~/Developer/configuration
```

Apply the configuration for the first time:

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#mac
```

Authenticate GitHub after `gh` is installed by the flake:

```sh
gh auth login --hostname github.com --git-protocol ssh --scopes "repo,read:org,gist"
```

Create the SSH key used for Git commit signing if it does not already exist:

```sh
test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -C "$(hostname)" -f ~/.ssh/id_ed25519
```

Add the public key to GitHub as a signing key:

```sh
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "$(hostname)-signing"
```

## Shell Helpers

| Command | Action |
|---------|--------|
| `kp <port>` | Kill the process listening on a port. |
| `tdl [agent ...]` | Open a tmux coding layout with the editor on the left and optional agent panes on the right. |
| `dr` | Apply the full nix-darwin configuration. |
| `hr` | Apply only the home-manager user configuration. |

## Keybindings

### tmux

| Key | Action |
|-----|--------|
| `Alt+h/j/k/l` | Focus pane left/down/up/right, passing through to Neovim when active. |
| `Alt+H/J/K/L` | Resize pane left/down/up/right. |
| `Alt+F` | Toggle floating shell. |
| `Ctrl+Alt+h/j/k/l` | Split pane left/down/up/right. |
| `Alt+t` | New window. |
| `Alt+w` | Close window. |
| `Alt+1-9` | Jump to window by number. |
| `Alt+[` | Enter copy mode. |
| `v` | Begin selection in copy mode. |
| `y` / `Enter` | Copy selection to clipboard and exit copy mode. |

### Neovim

`<leader>` is Space.

| Key | Action |
|-----|--------|
| `<leader>e` | Toggle file explorer. |
| `<leader>ff` | Find files. |
| `<leader>fb` | List buffers. |
| `<leader>f/` | Live grep. |
| `<leader>fh` | Search help. |
| `<leader>bc/bd/bo/bn/bp` | Create, delete, delete others, next, or previous buffer. |
| `<leader>tc/td/tn/tp` | Create, close, next, or previous tab. |
| `gd/gD/gr/gi` | Definition, declaration, references, or implementation. |
| `K` | Hover. |
| `<leader>r` | Rename. |
| `<leader>ca` | Code action. |
| `[d` / `]d` | Previous or next diagnostic. |
