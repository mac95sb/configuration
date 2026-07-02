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
- Since mise v2026.7.0, `[bootstrap.packages]` reimplements brew/brew-cask/apt/apk/dnf/pacman/mas natively (fetches formulae.brew.sh metadata, pours ghcr.io bottles, installs casks to `/Applications`) without requiring the `brew`/`mas` binaries to be present. Prefer this over a Brewfile for machine bootstrap: install mise itself via the curl installer (`curl https://mise.run | sh`), then declare formulae/casks/mas apps as `"brew:<formula>"`, `"brew-cask:<cask>"`, `"mas:<id>"` entries under `[bootstrap.packages]` and run `mise bootstrap packages apply`. Only fall back to an actual Brewfile for things this mechanism can't express (e.g. `brew services`, cask lifecycle scripts/completions, source-build DSLs it doesn't support).
- `brew`/`brew-cask` entries install into the standard Homebrew prefix (`/opt/homebrew` on macOS arm64) and never overwrite files they didn't create — if real Homebrew already owns a formula/cask there, `apply` reports link conflicts or "multiple Caskroom versions found" instead of silently succeeding. Treat that as a signal to reconcile (uninstall the brew-managed copy or accept mise's) rather than a bug, and always dry-run (`mise bootstrap packages apply --dry-run`) before applying against a machine with pre-existing Homebrew state.
- When migrating a Homebrew/asdf/nvm/etc. setup into mise, resolve conflicts by preserving migration intent: CLI/language runtimes go under `[tools]`; GUI apps, fonts, and system packages go under `[bootstrap.packages]`. Union non-conflicting additions from both sides instead of choosing ours/theirs wholesale.
- `mise activate <shell>` only ever prepends its own data dir (`~/.local/bin` for a curl install) to `PATH` — verify with `env -i HOME="$HOME" PATH=/usr/bin mise activate zsh | head`. It does not add `/opt/homebrew/bin`/`sbin`, so only add those manually if a configured `[bootstrap.packages]` entry actually installs a `binary` cask artifact (check `formulae.brew.sh/api/cask/<name>.json` artifacts) — otherwise it's dead PATH weight left over from a Homebrew-era rc file.
- `[bootstrap.mise_shell_activate]` cannot manage an rc file that `[dotfiles]` already tracks as a whole-file symlink target (e.g. `"~/.zshrc" = {}`) — `mise bootstrap mise-shell-activate apply` silently skips it (`mise bootstrap mise-shell-activate status -v` shows "skipped because `[dotfiles]` owns ~/.zshrc"). In that setup, hand-maintain the `eval "$(mise activate <shell>)"` line directly in the dotfile-tracked rc file instead of relying on the declarative block-insertion mechanism.

## Dotfiles bootstrap consistency

When using `[dotfiles]` to symlink config files, keep the install-side in sync:
- If a tool's config is tracked in `[dotfiles]`, its install entry (`[bootstrap.packages]` cask/formula, `[tools]` entry, etc.) must also exist. Missing the install side means a fresh machine gets the config symlink but not the app, causing silent drift.
- After adding a dotfile entry, cross-check `[bootstrap.packages]` (or `[tools]`) for the corresponding package. Audit in both directions when reviewing.

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
- Dotfiles bootstrap consistency: every tracked `[dotfiles]` entry has a corresponding install entry (`[bootstrap.packages]`/`[tools]`).
