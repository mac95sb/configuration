# Configuration

Personal macOS development environment configuration and home server
configuration.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/mac95sb/configuration/main/setup.sh | sh
```

## Layout

- `.config/` — dotfiles: shell, git, and the mise bootstrap config that
  provisions a new machine.
- `mise.toml` — one mise config for the whole system: dotfiles bootstrap
  and task entry points alike.
- `pitchfork.toml` — server daemons. `sudo pitchfork boot enable`
  registers pitchfork's own root LaunchDaemon; every service is then a
  `[daemons.x]` entry here with its own `user =`, rather than a separate
  plist per service. Don't use pitchfork's `auto = ["start", "stop"]` on
  any of them — that's a directory-triggered dev-workstation feature, not
  a fit for a daemon that should just start once and stay running.
- `fnox.toml` — server secrets, encrypted. Safe to commit: every value is
  encrypted to two age recipients (operational key, root-readable on
  disk; escrow key, held only in Apple Passwords). One profile per
  service, resolved at exec time via `fnox exec --profile <name>`.
- `hk.pkl` — the quality gate for this repo (git hooks + `mise run
  check`/`fix`). Catches things like a malformed `pitchfork.toml` or an
  accidentally-unencrypted secret before they land in git, plus
  `caddy validate` against `Caddyfile`.
- `Caddyfile` — reverse proxy config. Public ingress is a Cloudflare
  Tunnel, which terminates TLS at Cloudflare's edge and forwards to
  Caddy over plain HTTP locally — Caddy doesn't do its own ACME for
  publicly-reachable sites here, since port 80 is never publicly
  reachable to begin with.

## Secrets

Generate both age keypairs before `fnox.toml` does anything real:

```sh
age-keygen -o /etc/fnox/operational.key   # root-readable, referenced by FNOX_AGE_KEY_FILE
age-keygen                                # never saved to disk — see below
```

`/etc/fnox/` keeps the operational key off any user's home directory and
out of anything else on the host that might get backed up or synced
unencrypted; create it root-owned with `sudo install -d -m 700 -o root -g wheel /etc/fnox`
and lock the key itself down with `sudo chmod 400 /etc/fnox/operational.key`.

The escrow key's private half goes into Apple Passwords instead of a
file — not for day-to-day decryption (that's the operational key's job),
but so a from-scratch rebuild after losing the host entirely still has a
way in: `fnox.toml` encrypts to both public keys, so either private key
alone can decrypt it, and the escrow one is retrievable from Apple
Passwords on any device signed into the account, independent of the host
that died.

Put both printed public keys into `fnox.toml`'s `recipients` list.

## Service accounts

macOS has no declarative equivalent to `mise bootstrap accounts` (that
command is Linux-only). Each `[daemons.x]` entry's `user =` account is
created with a one-time `sudo sysadminctl -addUser ... -roleAccount` call
instead:

```sh
mise run accounts:install
```

## Supervisor

```sh
mise run daemon:install   # registers pitchfork to start on boot
mise run daemon:reload    # after editing pitchfork.toml
```
