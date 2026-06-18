# Configuration

This repo is the source of truth for macOS defaults, packages, Homebrew apps,
and user dotfiles managed through nix-darwin and home-manager.

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
ssh-keygen -t ed25519 -C "contact@maclong.dev"
gh auth login --hostname github.com --git-protocol ssh --scopes "repo,read:org,gist"
gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --type "authentication"
gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --type "signing"
```

The activation also wires up `.githooks` as the Git hooks directory for this
repo, so the `posix` branch syncs automatically on every subsequent commit.

## Formatting

Format Nix and Markdown files with the same formatter choices used by Neovim:

```sh
nix fmt
```

Check formatting without keeping changes:

```sh
nix build .#checks.aarch64-darwin.formatting
```

Lint Nix files:

```sh
nix build .#checks.aarch64-darwin.nix-lint
```

## Shell Helpers

| Command           | Action                                                                                       |
| ----------------- | -------------------------------------------------------------------------------------------- |
| `kp <port>`       | Kill the process listening on a port.                                                        |
| `tdl [agent ...]` | Open a tmux coding layout with the editor on the left and optional agent panes on the right. |
| `theme [name]`    | Interactively pick a colour scheme and apply it to Neovim and Ghostty.                       |
| `dr`              | Apply the full nix-darwin configuration.                                                     |
| `hr`              | Apply only the home-manager user configuration.                                              |

## POSIX Fallback Branch

After the first `darwin-rebuild switch`, home-manager wires up `.githooks` as
the Git hooks directory for this repo. After each subsequent commit,
`.githooks/post-commit` runs `scripts/sync-posix`, which strips Nix-specific
content from dotfiles and pushes the result to the `posix` branch.

That branch contains a generated `Brewfile` and portable copies of selected
dotfiles for machines where Nix is unavailable. See the `posix` branch README
for its own quick start.

## Keybindings

### tmux

| Key                | Action                                                                |
| ------------------ | --------------------------------------------------------------------- |
| `Alt+h/j/k/l`      | Focus pane left/down/up/right, passing through to Neovim when active. |
| `Alt+H/J/K/L`      | Resize pane left/down/up/right.                                       |
| `Alt+F`            | Toggle floating shell.                                                |
| `Ctrl+Alt+h/j/k/l` | Split pane left/down/up/right.                                        |
| `Alt+t`            | New window.                                                           |
| `Alt+w`            | Close window.                                                         |
| `Alt+1-9`          | Jump to window by number.                                             |
| `Alt+[`            | Enter copy mode.                                                      |
| `v`                | Begin selection in copy mode.                                         |
| `y` / `Enter`      | Copy selection to clipboard and exit copy mode.                       |

### Neovim

`<leader>` is Space.

| Key                      | Action                                                   |
| ------------------------ | -------------------------------------------------------- |
| `<leader>e`              | Toggle file explorer.                                    |
| `<leader>ff`             | Find files.                                              |
| `<leader>fb`             | List buffers.                                            |
| `<leader>f/`             | Live grep.                                               |
| `<leader>fh`             | Search help.                                             |
| `<leader>bc/bd/bo/bn/bp` | Create, delete, delete others, next, or previous buffer. |
| `<leader>tc/td/tn/tp`    | Create, close, next, or previous tab.                    |
| `gd/gD/gr/gi`            | Definition, declaration, references, or implementation.  |
| `K`                      | LSP hover.                                               |
| `<leader>r`              | Symbol rename.                                           |
| `<leader>ca`             | Code action.                                             |
| `[d` / `]d`              | Previous or next diagnostic.                             |
