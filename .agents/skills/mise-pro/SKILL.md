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

## External docs fallback

If this skill does not cover a requested mise setting, backend, task option, or best practice, search the official mise docs before answering or editing configuration. Match the installed mise version when behavior differs, and cite any external guidance used.

- [mise documentation](https://mise.jdx.dev/)
- [mise configuration](https://mise.jdx.dev/configuration.html)
- [mise tasks](https://mise.jdx.dev/tasks/)

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
- In Homebrew-based bootstrap docs, install `mise` through the Brewfile/Homebrew bundle rather than the curl installer when Homebrew is already part of the setup. After `eval "$(/opt/homebrew/bin/brew shellenv)"`, prefer simple `mise ...` commands over hardcoded `/opt/homebrew/bin/mise ...` paths unless the docs explicitly need to guard against another earlier `mise` on `PATH`.
- When rebasing or merging a migration from Homebrew/asdf/nvm/etc. into mise, resolve package-manager conflicts by preserving the migration intent: keep Homebrew/Brewfile only for bootstrap packages, packages mise cannot manage, or App Store `mas` entries, and put CLI/app/runtime tools under `[tools]`. Union non-conflicting tool additions from both sides instead of choosing ours/theirs wholesale.
- If shell activation was introduced before the installer path stabilized, avoid hardcoding only `~/.local/bin/mise`; prefer `command -v mise`, then known package-manager paths such as `/opt/homebrew/bin/mise`, then legacy fallbacks.
- For app state directories such as `~/.hermes`, prefer minimal file-level dotfile entries plus deny-by-default nested `.gitignore` files over symlinking/tracking the whole directory. See `references/hermes-minimal-dotfiles.md` for a concrete Hermes pattern.

## Review checklist

- Correct file scope, PATH/tool activation order, version pinning, task reproducibility, platform portability, secret safety, and startup performance.
