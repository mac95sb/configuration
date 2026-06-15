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
ssh-keygen
gh auth login --hostname github.com --git-protocol ssh --scopes "repo,read:org,gist"
```

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
| `dr`              | Apply the full nix-darwin configuration.                                                     |
| `hr`              | Apply only the home-manager user configuration.                                              |

## POSIX Fallback Branch

Home Manager configures this repository to use `.githooks` as its Git hooks
directory. On commit, `.githooks/pre-commit` runs `scripts/sync-posix`, which
updates a separate `.git/posix-worktree` checkout for the `posix` branch.

That branch contains a generated `Brewfile` and raw copies of selected
Nix-managed files from `$HOME` for machines where Nix is unavailable.

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
