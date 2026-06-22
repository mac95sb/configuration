---
name: vim9-pro
description: Vim 9 and Vim9script guidance. Use when editing vimrc, ftplugins, syntax files, mappings, commands, autoload plugins, or Vim9script code.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# Vim 9 Pro

- Inspect existing `.vimrc`, `vimrc`, `plugin/`, `autoload/`, `ftplugin/`, and `after/` layout before changing behavior.
- Prefer Vim 9-compatible patterns and Vim9script for new script files when the project already uses it; otherwise preserve legacy Vimscript style.
- Keep mappings non-recursive (`nnoremap`, `xnoremap`, etc.) unless recursion is intentional. Include `<silent>` and `<leader>` conventions already used.
- Use augroups with `autocmd!` to avoid duplicate autocmds.
- Prefer buffer-local options and mappings in ftplugins.
- Avoid global side effects from plugin files; put reusable functions under `autoload/`.
- Validate syntax with `vim -Nu NONE -n -es -S` or project test scripts when practical.

## Native fuzzy file finding without plugins

When configuring plugin-free project file finding in `.vimrc`:

- Start from Vim's native command-line completion: `wildmenu`, `wildmode`, `wildoptions=fuzzy`, and existing `path+=**` if present.
- Do not assume `getcompletion({query}, 'file_in_path')` finds hidden nested paths. In practice it can miss files under dot-directories such as `.config/mise/config.toml`, even when `path+=**` is set.
- For commands like `:Find`/`:F` that need fuzzy project files including dot-directories, use a custom `-complete=customlist` function that recursively scans from `.` with `readdir()`, keeps relative paths, includes dot-directories such as `.config`, and explicitly skips noisy directories (`.git`, `node_modules`, `dist`, `build`, `target`) and symlink directories to avoid runaway traversal.
- Filter results through `wildignore`, sort/`uniq`, then apply Vim's native `matchfuzzy()` so `:Find conf<Tab>` can offer nested relative paths like `.config/git/config` and `.config/mise/config.toml`.
- Lowercase user commands are not allowed in Vim. If the user wants `:f`, implement a command-line abbreviation that expands `:f` to a capitalized custom command such as `:Find`, and document that the original `:file` remains available by spelling `:file` explicitly.
- Verify both completion and opening behavior non-interactively, e.g. use `getcompletion('Find conf', 'cmdline')` to inspect custom completion and `vim -Nu /path/to/.vimrc -n -es +'Find config.toml' +...` to confirm the expected nested file opens.

## Native fuzzy file finding without plugins

When configuring a minimal `.vimrc` for fuzzy file finding, build on Vim's built-in command-line completion instead of introducing plugins:

- Inspect the existing `wildmenu`, `wildmode`, `wildoptions`, `path`, `wildignore`, and mappings first; preserve the user's current style and leader conventions.
- A compact native baseline is:
  - `set wildmenu`
  - `set wildmode=longest:full,full`
  - `set wildoptions=pum,fuzzy` on Vim versions that accept it
  - `set path+=**` for recursive `:find` lookup
  - `set wildignore+=...` for heavy/generated directories such as `.git/**`, `node_modules/**`, `dist/**`, `build/**`, `target/**`
- Add mappings around built-in `:find` rather than shelling out or installing dependencies, e.g. `<leader>f :find `, `<leader>F :sfind `, `<leader>v :vert sfind `, `<leader>t :tabfind `.
- Verify both option support and behavior with real Vim commands, for example checking `set wildoptions?` and confirming `:find <known-file>` opens the expected file.
