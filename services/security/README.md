# Protected service deployment (macOS)

Use **`services/security` as the single deployment path** for tools, fnox, backup,
Pitchfork, log capture, and activation. Keep Pitchfork; do not run the older backup
installer as a second installation step.

Deployment is an explicit administrative trust boundary. Review the checkout,
selected mise binaries, backup sources, and the provenance of the fnox configuration
before approving sudo. Root deployment accepts **declared age providers only**,
including all profile overrides and provider references. It rejects other provider
types, command/auth hooks, imports, plugins, leases, push targets, and managed files.
Supporting these features requires a deliberate security-code change, not just a
config edit. Never refresh deployed configuration from a scheduled task or
unprivileged service.

## Authoritative deployment commands

Run the helper from any reviewed checkout, including a temporary bootstrap checkout
outside `/Users/mac/Developer`. It derives the repository from its own location and
selects mise tools in that checkout, not in the caller's working directory.
For a fresh shell without mise on PATH, it first uses `$HOME/.local/bin/mise`.
Only when that path is absent does it use `command -v mise`; a present but
non-executable/broken fixed path fails rather than falling back. `MISE_BIN` is not
used. HOME/PATH discovery is confined to this explicit deployment step; root runtime
startup still uses fixed protected paths and a clean environment.

```text
/bin/sh services/security/deploy.sh deploy [reviewed_fnox_config_path]
/bin/sh services/security/deploy.sh stage [reviewed_fnox_config_path]
/bin/sh services/security/deploy.sh tools
/bin/sh services/security/deploy.sh config
```

The optional positional config path is accepted only by `deploy` and `stage`.
It defaults to **that checkout's** `fnox.toml`. Relative overrides are relative to
the caller's original working directory. The source may be root-only: it is
validated/read by the elevated installer, not by the unprivileged shell. Only
explicit deployment uses checkout code; installed runtime entry points never
execute the bootstrap checkout as root.

### Clean reinstall / offline recovery

Accounts can be provisioned from the bootstrap checkout with
`/bin/sh .mise/tasks/accounts/install`; that task has no final-checkout references.
**Before decrypting, extracting, or trusting any capsule content**, recovery must
compare the SHA-256 of the exact encrypted capsule bytes with an independently held trusted
digest from the backup-time offline recovery record. The backup flow must print
that record, and its digest must be kept out of band, not recovered solely from
the same bucket/download as the capsule. A newly computed hash or adjacent checksum
file from that source is not an independent trust anchor. Missing or mismatched
trusted digests must stop recovery before extraction, file provisioning, or root
deployment.

Age's AEAD checks ciphertext integrity, **not sender authenticity**. Anyone with the
public recipient can encrypt a different capsule that decrypts successfully.
Decryption alone therefore does not establish that a capsule came from an approved
backup. The backup/recovery flow owns the mandatory digest check and offline record;
this deployment helper receives only the already extracted, independently verified,
reviewed config. It does not download/decrypt capsules or verify their digest itself.

Only after verification, provision the protected operational identity and recovered
password files before staging. Then, from the reviewed bootstrap checkout:

```sh
/bin/sh services/security/deploy.sh stage /absolute/path/to/capsule-config.toml
```

Replace the example path with the actual reviewed config recovered from the capsule.
It may differ from Git's `fnox.toml`; do not silently substitute the Git version.
`recover.sh` should call this same `stage` action with its recovered config path.

**`stage` installs tools/Python, secret/backup/logging launcher files, the backup
helpers, `/etc/fnox/config.toml`, and its environment whitelist only.** It does not
read/install `pitchfork.toml`, install a launchd plist, prepare logging/newsyslog,
register jobs, start a supervisor, or run service-control commands. Merely copying
the protected logging/activation helper files does not run them. Stage does not
remove existing jobs/configuration; offline recovery requires existing server jobs
and processes to be absent, as enforced by the coordinator.

The recovery entry point is:

```text
sudo /usr/local/libexec/mac-server/backup/launch.sh restore SNAPSHOT --session SESSION --repository REPOSITORY --offline
```

After recovery has restored the final checkout and required unprivileged service
files, deploy from that restored checkout, preserving the reviewed recovered config:

```sh
/bin/sh services/security/deploy.sh deploy /etc/fnox/config.toml
/bin/sh .mise/tasks/daemon/activate
```

Reading and atomically replacing the same protected fnox path is supported. These
are the full-deployment and explicit activation steps; do not activate the server
before offline restore. A normal non-recovery install can omit the config override
to use the reviewed checkout's `fnox.toml`.

## Complete setup workflow

1. Pin/install a standalone mise Python 3.11+ and all tools, including restic.
   Python `3.12.14` was installed when this implementation was checked; the
   deployment selects the current installed Python with `mise where python` and
   the other tools with `mise which`. It does not install/download missing tools.
2. Run account setup. Provision `/etc/fnox` as a real root-owned directory, mode
   `0700`, and `/etc/fnox/operational.key` as a root-owned regular file, mode `0600`.
   Use a dedicated operational age identity. Its public recipient must already be
   included in the ciphertext for every operational profile. Adding a recipient
   alone does not re-encrypt old ciphertext. These tasks do not generate, display,
   decrypt, rotate, or remove keys.
3. Review the inputs, then run **`mise run daemon:install`**. On an existing server,
   deploy and activate together in a maintenance window: log ownership migration
   can affect an old shipper reopening its sink, and a running supervisor may
   notice changed configuration. Deployment installs protected
   tools/Python, launchers, the backup runtime, root-only fnox config, Pitchfork
   config, log directories/sinks, newsyslog config, and the boot plist. It does
   **not** start/stop services, bootstrap launchd, or decrypt secrets.
4. During an explicit maintenance window, run **`mise run daemon:activate`**.
   Setup can call this task explicitly after successful deployment. It validates
   the installed entry chain using the OS Python before executing the protected
   runtime; it never follows an old Python symlink into a user's mise tree.
   Activation then:
   - prepares/preserves the fixed log directories and newsyslog configuration;
   - disables respawn of loaded legacy `gui/<mac-uid>/pitchfork` and
     `system/pitchfork` launchd jobs;
   - gracefully stops the mac supervisor's daemons (`stop --all`) and supervisor,
     then any existing root supervisor's daemons and supervisor;
   - boots out the old jobs, enables the system job, and bootstraps the protected
     `/Library/LaunchDaemons/pitchfork.plist`;
   - checks that the new root supervisor becomes ready.
   Unknown supervisor state, failed stops, or launchctl errors abort activation
   rather than starting a duplicate. A failed maintenance attempt can leave old
   jobs disabled/stopped; fix the reported cause and rerun `daemon:activate`.

`daemon:relink` refreshes tool copies/Python only. `daemon:reload` stages reviewed
Pitchfork config, logging setup, and the boot plist, without restarting services.
Refresh fnox config and its whitelist together with `daemon:install` when profiles
or secret names change; activate explicitly afterward when needed.

No `setup.sh`, `mise.toml`, `fnox.toml`, backup source, or observability source edits
are part of this implementation. Their owners must integrate the setup call and
any tool pins. Service accounts must already be able to traverse/read their
intended unprivileged checkout files. The legacy fnox group/account/data paths
remain for migration, but known service/mac memberships are revoked and the
shared group is no longer granted. `staff` is not used for secrets.

## Root runtime boundary

- Deployment atomically copies reviewed fnox ciphertext to
  `/etc/fnox/config.toml`, root:wheel `0600`; the source is unchanged.
- `/usr/local/libexec/mac-server/secret-service` accepts exactly `forgejo`, `alloy`,
  or `grafana`, with no command/profile overrides. It starts with a clean root
  environment and `/var/empty` cwd. The fixed profiles are `forgejo`,
  `observability`, and `grafana,notifications`, respectively.
- The parent passes the protected identity as `FNOX_AGE_KEY` in its root process
  environment, never argv. This is necessary because provider-specific `identity`
  and `key_file` settings outrank `FNOX_AGE_KEY_FILE`.
- A protected second stage invokes `/usr/bin/sudo -n -H --preserve-env=NAME,...`
  with an explicit deployed whitelist. It drops to `svc_forgejo` or
  `svc_observability` **before** opening checkout scripts/config, Homebrew
  executables, or Grafana assets. It does not preserve the identity or fnox controls.
- Service whitelists use explicit selected-profile keys plus inherited top-level
  secrets. Environment controls for loaders, interpreters, shell startup, sudo,
  fnox, Pitchfork, and password-command/config overrides are rejected before
  deployment. Whitelists are generated without decrypting values.
- Fnox's global configuration is pinned with `FNOX_CONFIG_DIR=/etc/fnox`, the same
  protected configuration used by the explicit `--config` argument. No separate
  root-home global config or imported file can supply unvalidated providers/hooks.
- Root Pitchfork commands use root HOME, `PITCHFORK_USER=root`, protected global
  configuration (`XDG_CONFIG_HOME=/etc`), and `/var/empty` cwd. Client auto-start is
  disabled, so recovery/log readers cannot accidentally create another supervisor.
  Pitchfork uses `/bin/sh -c` explicitly, without mise wrapping, so root commands
  cannot resolve a user/Homebrew shell through PATH. The boot plist runs
  `/usr/local/bin/pitchfork supervisor run --boot` as root with
  `KeepAlive`. State and IPC belong to root, not mac.

Deployed executable/config files are root-owned regular files, published by
same-directory temporary file, `fsync`, and atomic replacement. Destination file
symlinks are replaced rather than followed. Unsafe parent ownership, write access,
symlinks, and extended ACLs are rejected. Only the fixed macOS `/etc` and `/var`
aliases are normalized. After validating each newly created directory, deployment
uses descriptor-based chmod to apply its intended mode despite umask `077`: public
runtime ancestors are `0755`, private directories remain `0700`. Existing directories
are never silently widened. Unsafe ownership/write access or insufficient required
access fails with an explicit review error; an old `0700` runtime directory must be
repaired deliberately, not by recursively relaxing `/etc/fnox` or other secret paths.
Explicit ownership migration is limited to the fixed log
**data** directories/files described below, not code or configuration parents.

## Python and backup

`/usr/local/bin/python3` is a root-owned regular wrapper around a complete copied
mise Python distribution under `/usr/local/libexec/mac-server/python-*`. It always
uses `-I -S`: no user import paths, site packages, `.pth` hooks, or Python environment
settings. OpenSSL configuration is disabled and its module search is pinned inside
the protected runtime. External Mach-O dependencies/rpaths other than OS libraries
are rejected; relocation and key standard-library extensions are checked before
publishing the wrapper. A Homebrew/framework Python requiring user-owned libraries
is not a fallback. Old copied runtime trees are retained for running processes;
remove unused trees only during maintenance.

The canonical backup runtime is **`/usr/local/libexec/mac-server/backup`**. The
security deployment copies the backup agent's reviewed helpers there. Python paths
are adapted only in the installed copies; source files are not rewritten. The old
`/usr/local/libexec/home-backup/launch.sh` becomes a forwarding compatibility wrapper.
Other legacy files/data remain untouched; there is no second active helper tree or
second installer in this workflow. `BACKUP_FILES` excludes the removed backup
`install.py`. The protected `mac-server/install.py` is the security deployment
helper used by activation, not a second backup installer.

Both installed launch wrappers forward arguments to the protected dispatcher:

```text
launch.sh                              # defaults to backup
launch.sh init
launch.sh backup
launch.sh checkpoint
launch.sh prune [--apply]
launch.sh verify SNAPSHOT [--repository REPOSITORY]
launch.sh restore SNAPSHOT --session SESSION [--repository REPOSITORY] [--offline]
```

- Snapshot IDs must be exact 64-character lowercase hex IDs, not `latest`/prefixes.
- Session names follow the coordinator's `[a-zA-Z0-9_-]+` rule.
- `--repository` belongs after `verify`/`restore` and is recovery-only. Overrides
  accept absolute local paths or `rclone:remote:path`, with no control characters
  or parent traversal. Command-spawning backends such as sftp are not accepted.
- `--fixture`, arbitrary commands/options, abbreviated options, and courier
  dispatch are never accepted by this privileged entry point. Courier tasks should
  run the installed `backup/courier.py` directly as the unprivileged mac account.

After fnox resolves the fixed `backup` profile, a protected second stage discards
the identity and all unrelated environment variables. The root coordinator receives
only fixed root/Pitchfork settings and explicitly declared backup-profile values
from the installer’s `BACKUP_ENV` allowlist: R2 backend/connection settings and
R2/AWS credential variables. Inherited application secrets, fnox controls, alternate
rclone config paths, and restic password commands do not reach it. The coordinator
still gets its restic password through its protected age/password-file path.

The coordinator's parser and global-service-control path were inspected for this
integration. A full transitive backup/restore audit remains the backup owner's
responsibility; deployment rejects literal checkout references in executable
helpers but that is not a complete runtime audit. No backup/restore was run here.

## Protected logs and rotation

The Pitchfork log daemon runs only the installed
`/usr/local/libexec/mac-server/ship-pitchfork.sh` as root. Its protected Python
reader uses a fixed list of `global/...` daemon IDs with
`pitchfork logs --json --follow --no-pager -n 0`. It excludes itself, preventing
error feedback loops. It does not load a secret profile or inherit identity/secret
environment variables, and it never runs a user-owned shipper as root.

Logging setup preserves existing contents and creates/migrates these fixed paths:

| Path | Owner/group | Mode |
| --- | --- | --- |
| `/var/log/services` | root:observability | 0750 |
| `/var/log/services/pitchfork.log` | root:observability | 0640 |
| `/var/log/services/supervisor.log` | root:observability | 0640 |
| `/var/log/services/postfix.log` | mac:observability | 0640 |
| `/var/log/caddy` | svc_caddy:observability | 0750 |

Sink opens refuse symlinks, non-regular files, hardlinks, wrong ownership, and wrong
permissions. Capture reopens for every record, including after newsyslog rotation.
`/etc/newsyslog.d/services.conf` is an atomic root-owned copy of the protected
`newsyslog.conf`; it rotates pitchfork/postfix sinks without signaling syslogd.
The low-volume launchd `supervisor.log` is not rotated by that configuration because
launchd holds its output descriptor open.

The postfix shipper remains unprivileged and must reopen its sink on rotation;
its source was not changed here. Applications must not print credentials: copying
application stdout cannot guarantee redaction of secrets applications themselves
log. Group membership grants access to these logs only, never to operational keys
or root supervisor state. SOC metrics remain once per minute.

## Forgejo

Forgejo trusts exactly one HTTP proxy hop from `127.0.0.1/32` under `[security]`.
Caddy must connect from that address and provide the actual client IP in
`X-Forwarded-For`/`X-Real-IP`. Its configuration and any upstream CDN trust are outside
this scope. This does not enable proxy authentication or affect SSH client IPs.

References checked:
- https://fnox.jdx.dev/providers/age.html (identity precedence).
- https://fnox.jdx.dev/reference/configuration.html (global config merging,
  profile provider overrides, command hooks, imports, and extension features).
- https://forgejo.org/docs/latest/admin/config-cheat-sheet/ (proxy settings);
  installed Forgejo reported 16.0.4.
- Installed Pitchfork 2.20.0 CLI help (foreground boot, logs, graceful stop, env names).
- https://raw.githubusercontent.com/jdx/pitchfork/v2.20.0/src/cli/supervisor/status.rs
  (`up`/`down`/`unknown` JSON states, without starting a supervisor). The installed
  CLI's read-only status check also returned a plain top-level `status`/`error`
  object; `unknown` remains an activation error, not permission to start a duplicate.

## Fixture validation

Run `python3 -I -S services/security/test_security.py` with Python 3.11+.
Tests mock all privileged execution, launchctl, fnox, activation and log readers.
They use only fixture sinks/keys and never decrypt, install a runtime, or contact
live services. Parser compatibility checks execute only the coordinator's argparse
construction, not its operational code.
