# macOS Configuration Files

A set of simple and effective macOS terminal tooling configurations.

## Quick Start

```sh
curl -fsSl https://raw.githubusercontent.com/mac95sb/configuration/refs/heads/main/setup.sh
```

> [!NOTE]
> This script will backup your old `~/.config` directory before cloning, you can locate this backup in your home directory.

---

## Shell Functions

| Command | Action |
|---------|--------|
| `kp <port>` | Kill the process listening on a port |
| `tdl [agent ...]` | Open a tmux coding layout: editor left, optional agent pane right, shell bottom |
| `ghi user/repo [...]` | Install latest macOS arm64 release binaries from GitHub repos into `~/.local/bin` |
| `nvim_deps` | Install non-Node external tools required by `nvim/init.lua` |
| `dev_build` | Build the Void-based `local/dev-void:latest` machine image |
| `dev_recreate` | Rebuild the image and recreate the `dev` machine from it |

---

## Dev Machine

The `dev` machine is built from `Containerfile`. It keeps Node and npm tooling off the host while providing:

- Neovim language servers: Pyright, TypeScript, Vue, and basedpyright
- Python/FastAPI tooling: uv, pipx, ruff, black, mypy, pytest, FastAPI, Uvicorn, Gunicorn
- Vue/TypeScript/Vite tooling: TypeScript, Vite, vue-tsc, Vue language server
- Azure deployment tooling: Azure CLI and Azure Static Web Apps CLI

Build or refresh it with:

```sh
dev_recreate
```

When the `dev` machine is stopped, Neovim skips container-backed language servers. After starting it with `dev`, reopen the buffer or run `:LspEnableAvailable`.

---

## Keybindings

### Vim (`<leader>` = `Space`)

#### Buffers

| Key | Action |
|-----|--------|
| `<leader>bc` | New buffer |
| `<leader>bd` | Delete buffer |
| `<leader>bo` | Delete all other buffers |
| `<leader>bn` | Next buffer |
| `<leader>bp` | Previous buffer |

#### Tabs

| Key | Action |
|-----|--------|
| `<leader>tc` | New tab |
| `<leader>td` | Close tab |
| `<leader>tn` | Next tab |
| `<leader>tp` | Previous tab |

#### Files & Search

| Key | Action |
|-----|--------|
| `<leader>e` | File explorer (netrw) |
| `<leader>ff` | Find file |
| `<leader>fb` | List buffers |
| `<leader>f/` | Grep search |
| `<leader>fh` | Help search |

#### Other

| Key | Action |
|-----|--------|
| `gc` | Toggle comment (normal & visual) |

---

### tmux 

#### Panes

| Key | Action |
|-----|--------|
| `Alt+h/j/k/l` | Focus pane left/down/up/right |
| `Alt+H/J/K/L` | Resize pane left/down/up/right |
| `Alt+Enter` | Split horizontal |
| `Alt+Shift+Enter` | Split vertical |
| `Ctrl+Alt+h` | New pane to the left |
| `Ctrl+Alt+j` | New pane below |
| `Ctrl+Alt+k` | New pane above |
| `Ctrl+Alt+l` | New pane to the right |

#### Windows

| Key | Action |
|-----|--------|
| `Alt+t` | New window |
| `Alt+w` | Close window |
| `Ctrl+Alt+<` | Move window left |
| `Ctrl+Alt+>` | Move window right |
| `Alt+1–9` | Jump to window by number |

#### Copy Mode

| Key | Action |
|-----|--------|
| `Alt+[` | Enter copy mode |
| `v` | Begin selection |
| `y` | Copy selection and exit |

#### Misc

| Key | Action |
|-----|--------|
| `Alt+r` | Reload tmux config |
