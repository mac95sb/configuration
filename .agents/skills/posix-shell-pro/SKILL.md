---
name: posix-shell-pro
description: POSIX sh guidance. Use when writing or reviewing portable shell scripts, install scripts, CI snippets, or /bin/sh code.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# POSIX Shell Pro

- External docs fallback: if this skill does not cover a requested POSIX shell behavior, portability rule, or scripting best practice, search the POSIX specification and ShellCheck guidance before answering or editing scripts. Match the target shell declared by the shebang or project docs, and cite any external guidance used.
  - [POSIX Shell Command Language](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
  - [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html)
  - [ShellCheck wiki](https://www.shellcheck.net/wiki/)
- Target `/bin/sh` portability unless the script shebang says bash/zsh/ksh. Do not use arrays, `[[ ]]`, process substitution, `pipefail`, or bash-only parameter expansion in POSIX scripts.
- Start scripts with `set -eu` only after checking unset-variable and conditional behavior; use `set -f` only when disabling globbing is intended.
- Quote variable expansions and command substitutions by default.
- Use `mktemp` for temp files and `trap` for cleanup.
- Prefer `printf` over `echo` for portable output.
- Handle paths with spaces, empty variables, failed commands, and partial downloads/writes.
- Validate with `sh -n`, ShellCheck when available, and a real run on disposable inputs.
