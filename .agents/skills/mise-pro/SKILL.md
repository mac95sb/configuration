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

## Dotfiles bootstrap consistency

When using `[dotfiles]` to symlink config files, keep the install-side in sync:
- If a tool's config is tracked in `[dotfiles]`, its install entry (Brewfile cask, `[tools]` entry, etc.) must also exist. Missing the install side means a fresh machine gets the config symlink but not the app, causing silent drift.
- After adding a dotfile entry, cross-check the Brewfile (or `[tools]`) for the corresponding package. Audit in both directions when reviewing.

## Docker/Alembic stale volume pitfall

When a mise task starts Docker Compose and the alembic container fails with:
`Can't locate revision identified by '<revision-id>'`
the repository migrations are usually fine. The local Docker Postgres volume can contain stale `alembic_version` rows pointing to revisions that were renamed, removed, or never existed in the checked-out code.

Wipe the local Postgres volume and rerun:
```bash
docker compose down -v
mise install
```
If the volume must be preserved, start Postgres and delete the bad rows from every tenant DB's `alembic_version` table instead.

## Teardown behavior

The default `mise run teardown` should stop Compose and remove containers + build images without wiping Docker volumes. Pass `--volumes` to also remove volumes.

This matters because later `mise install` / seeding will preserve any locally seeded data, permissions, or CMS-cached rows in the Postgres volume.

## Seed retry pattern

The backend loads CMS metadata asynchronously on startup in production-like flows, but local readiness checks only wait for the HTTP server. This means seed scripts can transiently fail with missing `CourseNode` data after `mise run dev` starts.

Add bounded retry with backoff around seed commands instead of hard-failing on first attempt. For the project's `mise run seed`, retry `/tmp/seed_test_data.py` up to 10 times with 5s backoff.

## Review checklist

- Correct file scope, PATH/tool activation order, version pinning, task reproducibility, platform portability, secret safety, and startup performance.
- Dotfiles bootstrap consistency: every tracked `[dotfiles]` entry has a corresponding install entry (Brewfile/`[tools]`).
