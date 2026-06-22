---
name: posix-shell-pro
description: POSIX sh guidance. Use when writing or reviewing portable shell scripts, install scripts, CI snippets, or /bin/sh code.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# POSIX Shell Pro

- Target `/bin/sh` portability unless the script shebang says bash/zsh/ksh. Do not use arrays, `[[ ]]`, process substitution, `pipefail`, or bash-only parameter expansion in POSIX scripts.
- Start scripts with `set -eu` only after checking unset-variable and conditional behavior; use `set -f` only when disabling globbing is intended.
- Quote variable expansions and command substitutions by default.
- Use `mktemp` for temp files and `trap` for cleanup.
- Prefer `printf` over `echo` for portable output.
- Handle paths with spaces, empty variables, failed commands, and partial downloads/writes.
- Validate with `sh -n`, ShellCheck when available, and a real run on disposable inputs.
