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
- `pitchfork.toml` — server daemons. Symlinked to `/etc/pitchfork/config.toml`
  by `mise run daemon:install`, so it's pitchfork's *global* config, not a
  project-local one — project configs only activate via `pitchfork project
  enter`/interactive sessions, they don't start at boot. Every service is a
  `[daemons.x]` entry with its own `user =` and `boot_start = true`, rather
  than a separate plist per service. `settings.supervisor.user` keeps the
  root-run supervisor's state/sockets under a real user's home instead of
  root's. Don't use pitchfork's `auto = ["start", "stop"]` on any daemon —
  that's a directory-triggered dev-workstation feature, not a fit for one
  that should just start once and stay running.
- `fnox.toml` — server secrets, encrypted. Safe to commit: every value is
  encrypted to two age recipients (operational key, root-readable on
  disk; escrow key, held only in Apple Passwords). One profile per
  service that actually needs a secret, resolved at exec time via
  `fnox exec --profile <name>` — a daemon with nothing to decrypt (Caddy,
  cloudflared) just runs directly, no fnox wrapper.
- `hk.pkl` — the quality gate for this repo (git hooks + `mise run
  check`/`fix`). Catches things like a malformed `pitchfork.toml` or an
  accidentally-unencrypted secret before they land in git, plus
  `caddy validate` against `Caddyfile` and `cloudflared tunnel ingress
  validate` against `cloudflared.yml`.
- `Caddyfile` — reverse proxy config. Public ingress is a Cloudflare
  Tunnel, which terminates TLS at Cloudflare's edge and forwards to
  Caddy over plain HTTP locally — Caddy doesn't do its own ACME for
  publicly-reachable sites here, since port 80 is never publicly
  reachable to begin with.
- `cloudflared.yml` — the tunnel's ingress rules (hostname → local
  port), declarative and safe to commit — no secrets in it. The actual
  secret is the tunnel's credentials file, which `setup.sh` generates
  (see Tunnel below) and isn't tracked in git.

## Secrets

Generate both age keypairs before `fnox.toml` does anything real:

```sh
age-keygen -o /etc/fnox/operational.key   # goes into /etc/fnox, see below
age-keygen                                # never saved to disk — see below
```

`/etc/fnox/` keeps the operational key off any user's home directory and
out of anything else on the host that might get backed up or synced
unencrypted. `fnox.toml`'s `key_file` points straight at it, so nothing
needs `FNOX_AGE_KEY_FILE` set at runtime. Every `[daemons.x]` entry that
calls `fnox exec` runs as its own service account (not root), so the key
can't be root-only 400 — it's owned by a shared `fnox` group instead,
readable only by accounts actually in that group:

```sh
sudo dseditgroup -o create fnox
sudo install -d -m 750 -o root -g fnox /etc/fnox
sudo install -o root -g fnox -m 440 /path/to/generated/operational.key /etc/fnox/operational.key
```

`mise run accounts:install` adds each service account to the `fnox`
group as it's created.

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

## Tunnel

`setup.sh` prompts "Is this the home server?" and, if yes, runs
`cloudflared tunnel login` (browser OAuth, can't be scripted further)
and `cloudflared tunnel create home-caddy` — skipped if credentials
already exist locally. This writes a credentials JSON to `~/.cloudflared/`,
which needs moving into place for the `svc_caddy` daemon to use it:

```sh
sudo install -d -m 755 -o root -g wheel /etc/cloudflared
sudo install -o svc_caddy -g staff -m 400 ~/.cloudflared/<tunnel-id>.json /etc/cloudflared/<tunnel-id>.json
```

Only `svc_caddy` can read it (400, owned by that account directly — no
shared group needed since nothing else uses it). Update `cloudflared.yml`'s
`tunnel` and `credentials-file` fields to match the ID, and add the DNS
route for any hostname in its `ingress` list:

```sh
cloudflared tunnel route dns home-caddy <hostname>
```

On a rebuild, the tunnel ID changes (a fresh `tunnel create`, since
locally-managed tunnel credentials can't be regenerated for an existing
tunnel) — repeat the steps above with the new ID.

## Supervisor

```sh
mise run daemon:install   # registers pitchfork to start on boot
mise run daemon:reload    # after editing pitchfork.toml
```

`daemon:install` also does two things service accounts need but mise
has no declarative way to express: symlinks each daemon's binary
(`fnox`, `caddy`, `cloudflared`) into `/usr/local/bin`, since service
accounts have no mise shims in `PATH` and can't traverse into
`/Users/mac` to reach mise's own install paths anyway; and grants
bare traverse-only access (`o+x`, no read) to `/Users/mac` itself, so
service accounts can reach the repo below it without exposing anything
else in the home directory.
