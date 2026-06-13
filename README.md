# configuration

Mac's nix-darwin system configuration. Manages macOS system settings, packages,
and dotfiles declaratively via nix-darwin, home-manager, nvf, and nix-homebrew.

## Quick Start

```sh
# 1. Install Lix (A Nix Implementation)
curl -sSf -L https://install.lix.systems/lix | sh -s -- install

# 2. Generate an SSH key and add it to GitHub
ssh-keygen -t ed25519 -C "$(hostname)" -f ~/.ssh/id_ed25519 -N ""
pbcopy < ~/.ssh/id_ed25519.pub
# → Add key at: https://github.com/settings/ssh/new

# 3. Clone this configuration
mkdir -p ~/Developer
git clone git@github.com:mac95sb/configuration ~/Developer/configuration

# 4. Apply the configuration
cd ~/Developer/configuration
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#mac
```

> [!NOTE]
> Night Shift schedule (sunset-to-sunrise) must be enabled once manually via
> **System Settings → Displays → Night Shift** after the first switch. The colour
> temperature is set automatically.

> [!NOTE]
> After first switch, log out and back in (or restart) for the Ctrl+1–9 desktop
> shortcuts and caps-lock → control remapping to take effect.

---

## Rebuild aliases

| Command | Action |
|---------|--------|
| `dr` | `sudo darwin-rebuild switch --flake ~/Developer/configuration#mac` |
| `hr` | `home-manager switch --flake ~/Developer/configuration#mac` |

---

## What's managed

| Layer | Tool | Covers |
|-------|------|--------|
| System | nix-darwin | firewall, keyboard, trackpad, Night Shift, dock |
| Packages | nixpkgs | neovim (nvf), tmux, git, zsh, LSP servers, formatters |
| GUI / Fonts | nix-homebrew + Homebrew casks | Ghostty, Claude Code, Codex, CrossOver, Steam, Liga SFMono Nerd Font |
| App Store | homebrew masApps | Final Cut Pro, Logic Pro, Xcode, Pages, Keynote, etc. |
| User config | home-manager | git, zsh, tmux, ghostty, neovim |

---

## Shell functions

| Command | Action |
|---------|--------|
| `kp <port>` | Kill the process listening on a port |
| `tdl [agent …]` | Open a tmux coding layout: editor left, optional agent panes right, floating shell on `Alt+F` |

---

## Keybindings

### Neovim (`<leader>` = `Space`)

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
| `<leader>e` | File explorer (mini.files) |
| `<leader>ff` | Find file |
| `<leader>fb` | List buffers |
| `<leader>f/` | Grep search |
| `<leader>fh` | Help search |

#### LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | References |
| `gi` | Implementation |
| `K` | Hover |
| `<leader>r` | Rename |
| `<leader>ca` | Code action |
| `[d` / `]d` | Prev / next diagnostic |

---

### tmux

#### Panes

| Key | Action |
|-----|--------|
| `Alt+h/j/k/l` | Focus pane left/down/up/right |
| `Alt+H/J/K/L` | Resize pane left/down/up/right |
| `Alt+F` | Toggle floating shell |
| `Ctrl+Alt+h` | New pane to the left |
| `Ctrl+Alt+j` | New pane below |
| `Ctrl+Alt+k` | New pane above |
| `Ctrl+Alt+l` | New pane to the right |

#### Windows

| Key | Action |
|-----|--------|
| `Alt+t` | New window |
| `Alt+w` | Close window |
| `Alt+1–9` | Jump to window by number |

#### Copy mode

| Key | Action |
|-----|--------|
| `Alt+[` | Enter copy mode |
| `v` | Begin selection |
| `y` / `Enter` | Copy selection and exit |
