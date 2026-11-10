# Backup implementation and limits

Runnable orchestration is in `.mise/tasks/backup/`, with local functions in
`_common`. Restic owns encryption, repository operations, snapshots, retention
and file readback. System `plutil` parses structured output; there is no extra
JSON parser runtime or repository-copy layer.

- Sole repository: mac's local iCloud `Backups/configuration/restic-sh-v1/repository`.
- Root-private work and installed recovery stages: `/var/db/home-backup`, mode 700.
- Private per-operation handoff: `/var/db/home-backup-handoff/session.*`. Only
  `mac` and root can access it. It contains the captured payload and temporary
  plaintext repository password, **never** the operational age identity.
- Encrypted password: `/etc/fnox/restic-password.age`; recipients come from the
  deployed restricted fnox config. Keep an independent recipient identity.

Root captures the entire Developer tree, including hidden, private and
uncommitted files. `node_modules`, `.build`, `__pycache__`, `.cache` and `Caches`
are excluded; symlinks are saved, not followed. Configuration and robin must
have complete internal `.git` directories, without alternates/shallow history.
Independent Git bundles support bootstrap; only Restic contains dirty files.

Both application states are inspected before stopping either. A missing, failed
or unrecognized status is fatal, including after a stop request. Only applications
previously running are restarted on success or ordinary failure/signals.
Full Forgejo/Grafana trees are copied while stopped; copied SQLite WAL is folded
into standalone databases without modifying live data. Git/SQLite integrity and
Restic's exact-snapshot `restore --verify` run before artifact publication and
the success metric. Developer is a file copy, not an APFS point-in-time snapshot:
avoid editing it during capture.

`/var/db/home-backup/shell.lock` is a fail-fast mkdir lock shared by backup,
deployment, activation and recovery installation. Ordinary exits/signals release
it. SIGKILL/power loss may leave the lock/private work/handoff behind; inspect
processes and data before administrative cleanup. Never run legacy backup writers
or writers on another host alongside this implementation. iCloud sync is not a
distributed transaction/locking service. Retain FileVault to protect temporary data.

Pruning is explicit and dry-run by default: check, then keep last 1, daily 7,
weekly 5 and monthly 12 for `home-mac` / `home-sh-v1`, grouped by host. Applied
pruning deletes from the sole repository and therefore propagates through iCloud.
Artifact folders are not automatically pruned; review storage manually.

Recovery always verifies into staging before installation. Final destinations
are reserved with mkdir so an existing directory cannot turn a move into nesting.
The bootstrap is moved inside a newly reserved private preservation container;
verified staging is retained. Partial installs require inspection, not blind retry.
Developer becomes mac:staff, Forgejo svc_forgejo:staff, Grafana
svc_observability:staff. Arbitrary mixed ownership is not preserved.

Allow space for capture, Restic and a full verification restore. This is not a
bootable image or a guarantee for ACLs/resource forks or external application
state. Uploaded bytes and an erased-host rehearsal must be validated separately
from the temporary-directory fixtures. Follow the root README's independently
trusted hash checks before cloning a downloaded bundle.
