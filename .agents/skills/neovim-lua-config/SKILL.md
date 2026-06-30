---
name: neovim-lua-config
description: >
  Neovim Lua dotfile maintenance for this user's lazy.nvim config.
  Use when editing plugins, LSP/mason setup, treesitter, blink.cmp,
  keymaps, or herdr-splits integration under .config/nvim/.
triggers:
  - editing nvim lua config
  - mason / lspconfig / treesitter setup
  - blink.cmp configuration
  - herdr-splits keybinding changes
  - nvim plugin troubleshooting
---

# neovim-lua-config

User's Neovim config lives at `~/.config/nvim/` (tracked in `~/Developer/configuration`).
Structure: `init.lua` → `lua/options.lua`, `lua/autocmds.lua`, `lua/keymaps.lua`, `lua/theme.lua`, `lua/plugins/*.lua`.
Plugin manager: **lazy.nvim**. Plugin files are auto-discovered from `lua/plugins/`.

## Plugin file layout

| File | Purpose |
|------|---------|
| `plugins/mason.lua` | mason.nvim + mason-lspconfig (server installer) |
| `plugins/lsp.lua` | nvim-lspconfig, lazydev, conform.nvim |
| `plugins/treesitter.lua` | nvim-treesitter |
| `plugins/completion.lua` | blink.cmp + blink-ripgrep |
| `plugins/herdr.lua` | herdr-splits.nvim (cond: HERDR_ENV=1) |
| `plugins/mini.lua` | mini.nvim suite |
| `plugins/markdown.lua` | render-markdown.nvim |
| `plugins/colorschemes.lua` | theme plugins |

## LSP server names (mason-lspconfig)

Use mason-lspconfig names (underscored), NOT lspconfig aliases:

| Language | Server name |
|----------|-------------|
| Vue | `volar` (NOT `vuels` — that's old Vetur) |
| TypeScript | `vtsls` |
| Emmet | `emmet_ls` |
| Nix | `nil_ls` |
| Markdown | `marksman` |
| Lua | `lua_ls` |
| Tailwind | `tailwindcss` |
| HTML | `html` |
| CSS | `cssls` |
| Python | `pyright` |

## blink.cmp pitfalls

See `references/blink-cmp-api.md` for full field map.

- `signature.documentation` — INVALID field, causes startup warning
- Correct: `signature.window.show_documentation = false`
- `completion.documentation.auto_show` — valid
- `fuzzy.implementation = "lua"` — valid (alternative: `"prefer_rust"`)

## herdr-splits keybinding changes

Changing keys requires updates in **two places**:

### 1. Neovim side — `plugins/herdr.lua`
Update the `keys = { ... }` table in the lazy spec.
Also update the plain-Neovim fallback in `keymaps.lua` to stay consistent.

### 2. Herdr multiplexer side — `~/.config/herdr/config.toml`
Update `[[keys.command]]` entries. Key format: `"alt+h"`, `"alt+shift+h"`, `"ctrl+h"`, etc.
After editing, reload: `herdr server reload-config`

Current layout (as of this session):
- Navigate: `alt+hjkl` → `herdr-splits.nav-{left,down,up,right}` (Neovim: `<M-hjkl>`)
- Resize: `alt+shift+hjkl` → `herdr-splits.resize-{left,down,up,right}` (Neovim: `<M-HJKL>`)

Key routing note: Herdr `plugin_action` intercepts keys before Neovim sees them.
The Herdr-side herdr-splits plugin detects when Neovim is the active pane and forwards the keystroke
into it — so both sides must use the same key (alt+hjkl). Neovim then handles within-split nav and
calls the herdr CLI when at an edge. DO NOT use ctrl for nav — ctrl is intercepted but not forwarded.

Note: `~/.config/herdr/config.toml` is NOT tracked in the dotfiles repo.

## References

- `references/blink-cmp-api.md` — blink.cmp configuration field map and pitfalls
