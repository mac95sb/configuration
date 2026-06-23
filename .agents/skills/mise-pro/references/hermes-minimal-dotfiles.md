# Hermes minimal dotfiles pattern

Use this when a dotfiles repo should manage a small, safe subset of `~/.hermes` via mise.

## Recommended minimal tracked set

Track only declarative, non-secret profile files by default:

- `.hermes/SOUL.md`
- `.hermes/memories/USER.md` only for private repos and when the content is intentionally shareable
- `.hermes/.gitignore` to keep the repo deny-by-default under `.hermes/`

Do not include `config.yaml`, skills, cron, hooks, auth, sessions, logs, databases, caches, or generated runtime state unless the user explicitly asks for a broader profile distribution.

## Deny-by-default `.hermes/.gitignore`

```gitignore
# Keep this repo's Hermes profile tracking minimal and secret-safe.
*

# Tracked declarative profile files.
!.gitignore
!SOUL.md
!memories/
!memories/USER.md
```

This protects against accidentally copying more of `~/.hermes` into the repo later.

## Mise dotfiles entries

Add only the tracked files to `[dotfiles]`:

```toml
"~/.hermes/SOUL.md" = {}
"~/.hermes/memories/USER.md" = {}
```

Prefer file-level dotfile entries over symlinking the whole `~/.hermes` directory. This keeps Hermes auth, sessions, logs, DBs, caches, and local runtime state outside version control.

## Verification

After editing:

- Run `mise config` to validate TOML/config loading.
- Run `git status --short --untracked-files=all .hermes` and confirm only the intended files appear.
