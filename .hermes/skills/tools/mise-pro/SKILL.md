---
name: mise-pro
description: Mise tool/version/task/dotfiles guidance. Use when configuring mise.toml, .mise.toml, mise tasks, language versions, environment variables, or dotfile/tooling bootstraps.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# Mise Pro

Use this skill for [mise](https://mise.jdx.dev/) configuration and workflows.

## Workflow

1. Inspect existing `.mise.toml`, `mise.toml`, `.config/mise/config.toml`, `.tool-versions`, task files, and project docs before changing anything.
2. Determine whether config is global/user or project-local. Do not move user-wide behavior into project config without reason.
3. Prefer idiomatic mise tables: `[tools]`, `[env]`, `[tasks.<name>]`, aliases, and backend-specific options already used by the repo.
4. Verify with real commands such as `mise doctor`, `mise ls`, `mise config`, `mise tasks`, or the specific `mise run <task>`.

## Conventions

- Pin tool versions intentionally. Use broad versions only when the project explicitly wants floating updates.
- Keep secrets out of mise config; use references to external secret managers or environment expected from the user.
- For tasks, specify `run`, `description`, dependencies, sources/outputs, and environment only when useful.
- Avoid shell-specific task syntax unless the project declares that shell.
- When replacing asdf/nvm/pyenv/rbenv/direnv flows, preserve behavior and document migration notes.
- For dotfiles, keep bootstrapping idempotent and safe to re-run.
- For app state directories such as `~/.hermes`, prefer minimal file-level dotfile entries plus deny-by-default nested `.gitignore` files over symlinking/tracking the whole directory. See `references/hermes-minimal-dotfiles.md` for a concrete Hermes pattern.

## Review checklist

- Correct file scope, PATH/tool activation order, version pinning, task reproducibility, platform portability, secret safety, and startup performance.
