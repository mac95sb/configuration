---
name: zsh-pro
description: Zsh configuration and scripting guidance. Use when editing .zshrc, zprofile, zshenv, completions, prompt setup, aliases, functions, or Zsh scripts.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# ZSH Pro

- Inspect `.zshenv`, `.zprofile`, `.zshrc`, plugin manager setup, completion setup, and PATH order before editing.
- Put environment needed by all shells in `.zshenv` only if it is safe for every zsh invocation; keep interactive UI in `.zshrc`; login-only setup in `.zprofile`.
- Avoid duplicate PATH entries; prefer array manipulation (`path=(...)`) and `typeset -U path PATH` when consistent with the file.
- Use `autoload -Uz compinit` and cache handling intentionally; avoid slow startup work on every shell launch.
- Quote expansions unless intentional glob/splitting is required. Use zsh arrays instead of stringly command construction.
- Keep aliases simple; use functions for arguments or logic.
- Verify with `zsh -n file` and, for startup changes, a non-destructive interactive shell timing/check.
