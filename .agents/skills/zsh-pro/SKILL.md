---
name: zsh-pro
description: Zsh configuration and scripting guidance. Use when editing .zshrc, zprofile, zshenv, completions, prompt setup, aliases, functions, or Zsh scripts.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# ZSH Pro

- External docs fallback: if this skill does not cover a requested Zsh option, startup file behavior, completion behavior, or best practice, search the official Zsh docs before answering or editing shell configuration. Match the user's installed Zsh version when behavior differs, and cite any external guidance used.
  - [Zsh documentation](https://zsh.sourceforge.io/Doc/)
  - [Zsh FAQ](https://zsh.sourceforge.io/FAQ/)
- Inspect `.zshenv`, `.zprofile`, `.zshrc`, plugin manager setup, completion setup, and PATH order before editing.
- Put environment needed by all shells in `.zshenv` only if it is safe for every zsh invocation; keep interactive UI in `.zshrc`; login-only setup in `.zprofile`.
- Avoid duplicate PATH entries; prefer array manipulation (`path=(...)`) and `typeset -U path PATH` when consistent with the file.
- Use `autoload -Uz compinit` and cache handling intentionally; avoid slow startup work on every shell launch.
- Quote expansions unless intentional glob/splitting is required. Use zsh arrays instead of stringly command construction.
- Keep aliases simple; use functions for arguments or logic.
- Verify with `zsh -n file` and, for startup changes, a non-destructive interactive shell timing/check.

## Pitfalls

### Undefined variable in plugin loop
A common pattern for loading Homebrew-installed Zsh plugins uses a variable for the share path:
```zsh
for plugin in "${plugins[@]}"; do
  [[ -r "$brew_share/$plugin" ]] && source "/opt/homebrew/share/$plugin"
done
```
If `$brew_share` is never assigned, the readability guard always fails silently and the plugins are never loaded — no error, no warning. Fix: either define `brew_share=/opt/homebrew/share` before the loop, or eliminate the variable and use the literal path in both the test and the source:
```zsh
for plugin in "${plugins[@]}"; do
  [[ -r "/opt/homebrew/share/$plugin" ]] && source "/opt/homebrew/share/$plugin"
done
```

### SHARE_HISTORY without HISTFILE/HISTSIZE/SAVEHIST
Setting `SHARE_HISTORY` (or `setopt SHARE_HISTORY`) without also setting `HISTFILE`, `HISTSIZE`, and `SAVEHIST` defaults to a 1000-line in-memory ring with a Zsh-determined location. Shell history is effectively silently truncated with no indication. Always set all three together:
```zsh
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_EXPIRE_DUPS_FIRST
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
```
- In tracked dotfiles, avoid committing machine-specific credential paths or private-key environment variables. For optional tools in `.zshrc`, guard startup hooks with `command -v tool >/dev/null 2>&1` so a fresh machine does not fail shell startup when the tool is absent.
