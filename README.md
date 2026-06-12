# macOS Configuration Files

A set of simple and effective macOS terminal tooling configurations.

## Quick Start

```sh
curl -fsSl https://raw.githubusercontent.com/mac95sb/configuration/refs/heads/main/setup.sh
```

> [!NOTE]
> This script will backup your old `~/.config` directory before cloning, you can locate this backup in your home directory.

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
