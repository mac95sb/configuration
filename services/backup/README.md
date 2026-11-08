# Restic backup and recovery

Backups use restic, a root-controlled runtime, and the existing fnox `backup` profile. **`services/security` is the only provisioning/deployment path.** There is no separate backup installer. Privileged recovery tasks and compatibility wrappers call `/usr/local/libexec/mac-server/backup/launch.sh` with an explicit command. The courier uses the separate unprivileged `/usr/local/libexec/mac-server/backup/courier.sh` entrypoint as mac.

## Runtime and storage

- Installed runtime: `/usr/local/libexec/mac-server/backup/`. Its launcher, coordinator, courier and recovery helpers are deployed together by security provisioning. The coordinator imports the adjacent `courier.py` for atomic metric publication; deploy both in the root-controlled directory.
- Tools: actual trusted binaries at `/usr/local/bin/{restic,rclone,age,fnox,pitchfork}`, not root symlinks into user-writable mise installs. The runtime uses the copied, protected Python 3.9+ interpreter at `/usr/local/bin/python3`, not system Python. System Git and macOS system tools are also prerequisites. Capsules carry the installed tools and SHA-256/version/platform metadata, but not a portable Python runtime.
- Root fnox files: `/etc/fnox/config.toml`, `/etc/fnox/operational.key`, `/etc/fnox/restic-password.age`. The directory is root `0700`; files are root `0600`; symlinks are refused. Security provisioning owns the config copy and key lifecycle.
- Primary repository: `rclone:R2:home-backups/restic-v1`, with existing fnox `backup` profile `RCLONE_*` credentials.
- Independent R2 recovery artifacts: `R2:home-backups/recovery-v1/`.
- Readable **encrypted** local repository mirror and recovery artifacts: `/var/db/home-backup-export/recovery-v1/`.
- mac's local iCloud handoff: `~/Library/Mobile Documents/com~apple~CloudDocs/Backups/configuration/recovery-v1/`. It includes an encrypted restic repository, not just a bootstrap bundle.
- Private root state/cache/restore sessions: `/var/db/home-backup/`, mode `0700`.

The root launcher allowlist is `backup`, `init`, `checkpoint`, `restore`, `verify`, `prune`; no arguments defaults to `backup`. These commands run root fnox with an explicit copied config, clean environment, and `FNOX_AGE_KEY_FILE=/etc/fnox/operational.key`. It does not accept `courier`: the separate courier executable runs as mac without resolving fnox credentials. Repository overrides are recovery-only options **after** `restore` or `verify`, not launcher command names.

Restic decrypts its password through an age password-command, never a password argv or plaintext password file during backup/restore. Explicit init generates a random password only after an authenticated listing proves the repository prefix empty. Existing repository objects plus a missing password cause refusal. Existing passwords are never replaced on access or decryption failure. Initialization alone briefly uses a private plaintext file while encrypting the new password.

## Capture, verification and service control

Mandatory sources fail the backup if missing or unreadable:

- Full `/Users/mac/Developer`: hidden/private files, untracked/ignored work, and Git directories. Names `node_modules`, `.build`, `__pycache__`, `.cache`, `Caches` are excluded at any depth. Symlinks are saved, not followed.
- Independent configuration and robin bundles, including detached HEAD when applicable.
- Full `/Users/svc_forgejo/forgejo-data`: database, repositories, assets, keys, attachments and other work-tree files.
- Full `/Users/svc_observability/grafana-data`.

The root supervisor is controlled directly with `/usr/local/bin/pitchfork status|stop|start global/forgejo` or `global/grafana`, always from `/var/empty` and never as the service users. Its explicit environment sets `PITCHFORK_SUPERVISOR_AUTO_START=false`, `PITCHFORK_USER=root` and `XDG_CONFIG_HOME=/etc`, so status cannot implicitly start a supervisor or select user configuration. Status JSON is checked for the exact `id`, `namespace`, `name` and a string status of `running`, `stopped` or `available`. This matches the reported live global status format. Unknown/unavailable supervisor state fails closed for normal backup/restore; verification needs no supervisor.

Both statuses are read before mutation. Only previously running daemons are stopped, only for their local file copies. `finally` resumes them after copy errors and ordinary HUP/INT/TERM; already stopped daemons stay stopped. No enable/disable state is changed. SQLite backup on the copied databases folds WAL into standalone databases and changes them to DELETE journaling before copied WAL/SHM removal. Source databases and WAL are never modified by this step. Services run during encryption, transfers and verification.

Each payload manifest records contents, types, owners/groups, modes, symlink targets, Git HEADs, timestamp, and named-account metadata. Exact-snapshot verification restores/read-checks the full 64-character snapshot ID, compares the original inventory, verifies both bundles/checkout HEADs, runs Git fsck on the checkouts and Forgejo repositories, and checks both SQLite databases. Symlink modes are not compared because macOS/restic recreate them with the restore umask; owners and targets are checked.

The mandatory checkouts have internal `.git` directories, no object alternates and no shallow history. Checkpoint requires clean source, captured and restored configuration/robin checkouts; submodules are rejected for checkpoint. Root Git commands disable hooks, fsmonitor and clean/smudge/process filters. Filtered/LFS checkouts can therefore fail the clean-content check rather than executing user filters as root. Avoid editing developer files during capture: the copy is not an APFS point-in-time snapshot.

## Commands and monitoring

```sh
mise run recovery:init
mise run recovery:checkpoint
mise run recovery:verify FULL_64_CHARACTER_SNAPSHOT_ID
mise run recovery:courier --snapshot FULL_64_CHARACTER_SNAPSHOT_ID
mise run recovery:prune
mise run recovery:prune --apply
```

Backup/checkpoint holds one non-blocking root mutation lock through capture, remote exact-snapshot readback, independent immutable R2 artifacts, repository mirroring, and mirror exact-snapshot readback. Checkpoint also holds it through mac's courier. The courier has its own local lock. The printed snapshot ID is the actual created ID, never a guessed latest snapshot.

After complete success, backup and checkpoint print one compact JSON line to stderr prefixed `OFFLINE_RECOVERY_RECORD `. It contains `schema: 1`, the full `snapshot`, and `capsule`, `bootstrap_bundle`, and `receipt` objects, each with its exact `filename` and `sha256`. Stdout remains only the full snapshot ID. The same record is stored as `recovery_record` inside root's `/var/db/home-backup/last-success.json`.

**Retain that record independently, together with the offline age identity, before erasing the host.** A paper copy or independently held offline storage is suitable; a receipt or record kept only beside the backups in the same bucket/iCloud is not an independent trust anchor. The recorded hashes are not secret, but their trusted provenance matters. Do not reconstruct the expected capsule or bundle hash from downloaded unsigned receipts or capsule metadata.

Receipts include the capture `created` Unix timestamp, snapshot ID, HEADs, artifact hashes and encrypted mirror hashes. Unique `configuration-TIMESTAMP-SNAPSHOT.bundle`, `capsule-TIMESTAMP-SNAPSHOT.tar.age` and `receipt-TIMESTAMP-SNAPSHOT.json` names are never overwritten. R2 artifacts use `copyto --immutable` and download-based checks. No mutable latest alias is needed.

By default the courier selects exactly one completed receipt with the highest finite, nonnegative numeric `created` timestamp, not the lexically newest filename. A tied newest timestamp is refused; `--snapshot ID` must match exactly one receipt. Receipt metadata is scanned once, then only the selected receipt's complete mirror and artifacts are hashed/copy-checked. Historical receipts do not trigger repeated repository scans. The courier uses atomic no-replace publication, checks bytes, refuses different destination contents and publishes the selected receipt last. It preserves all existing destination files and deletes nothing. Success means **local iCloud files exist**, not that Apple has uploaded or durably stored them. Confirm upload independently, preferably by downloading and verifying the exact snapshot on another machine before erasing the host.

Prometheus compatibility is preserved in `/Users/svc_observability/textfile`:

- `backup_last_success_seconds.prom` is published by root only after the complete backup pipeline (including local courier for checkpoint).
- `backup_courier_last_success_seconds.prom` is published by mac only after all requested local copies/checks succeed.

Metrics use completion time, not the capture timestamp. Each textfile is fsynced and atomically replaced, mode `0640`, group equal to `svc_observability`'s current primary group; owner is root for backup and mac for courier. The existing textfile directory must allow mac's courier to create/rename files and the collector to traverse/read them; mac also needs membership in that collector group to assign it on courier files. No metric advances on a failed capture or failed local-copy check. The root success receipt is also recorded at `/var/db/home-backup/last-success.json`.

Retention is dry-run unless explicitly invoked with `--apply`: check, then forget/prune with latest **1**, daily **7**, weekly **5**, monthly **12**, scoped to `home-mac`/`home-v1` and grouped by host. Normal backups never prune. Mirrors retain old objects/snapshots indefinitely; R2 pruning does not delete local/iCloud history. All writers/pruners use the coordinator lock; it cannot serialize an unrelated writer on another host. Legacy `daily`, `weekly`, `monthly` objects and archives are never deleted or migrated in place. Old tar/sync jobs are replaced through security's deployment flow, not run alongside this pipeline.

## Clean reinstall: restore first, then normal setup

**Do not run normal setup or clone into `/Users/mac/Developer/configuration` before restoring Developer.** Bootstrap into a separate temporary checkout outside `/Users/mac/Developer`, or use capsule scripts only after checking the capsule against the independently retained hash. The restore has no `--preserve-bootstrap` overwrite exception: all three final targets must be absent, and unrelated existing data is never merged or removed.

1. Retain at least one offline age recipient identity **and the offline recovery record** separately from the machine and cloud copies. Capsules do not contain an identity. Obtain the exact snapshot and filenames/hashes from that retained record, then download the capsule and matching bootstrap bundle/receipt from R2 or fully downloaded iCloud files. **Before cloning the configuration bundle or running any bootstrap code**, compute its SHA-256 with an already trusted local tool (for example `shasum -a 256 DOWNLOADED_CONFIGURATION_BUNDLE`) and compare it with the independently retained `bootstrap_bundle.sha256`. Stop if the record is missing or any digest differs. A matching downloaded unsigned receipt is not sufficient. Audit configuration Git history before publishing its unencrypted bundle: historical plaintext secrets cannot be certified absent by this code.
2. The main recovery entrypoint's positional interface is:
   ```text
   recover.sh CAPSULE IDENTITY SNAPSHOT CAPSULE_SHA256 [LOCAL_REPO]
   ```
   Supply `SNAPSHOT` and `CAPSULE_SHA256` from the independently retained record, not from downloaded metadata. Capsule SHA-256 verification must succeed **before any capsule decryption or recovery staging**. For direct extraction with an already trusted Python, extractor and age binary:
   ```sh
   /usr/local/bin/python3 services/backup/open_capsule.py CAPSULE.tar.age --identity OFFLINE_IDENTITY --sha256 CAPSULE_SHA256 --destination NEW_PRIVATE_DIRECTORY --age TRUSTED_AGE_BINARY
   ```
   Uppercase arguments select your local files and independently retained digest. The standalone extractor requires the digest and checks it before creating a destination or invoking age; it also refuses existing destinations, path traversal, symlinks and special files, and checks bundled tool hashes. It executes nothing. The capsule contains `config.toml.age`, unchanged `restic-password.age`, tools with metadata, installed scripts and instructions.

   **Age encryption is not sender authentication.** Its authenticated encryption protects confidentiality and detects modification of an existing ciphertext, but anyone knowing the public recipients can create a different, valid encrypted capsule containing replacement tools and matching internal hashes. Neither successful age decryption nor hashes inside that capsule establish its origin. The independently retained capsule SHA-256 pins the intended bytes without adding a signing-key lifecycle.
3. From the temporary bootstrap, use the **official security provisioning flow** to stage the trusted runtime/tools and private fnox files without starting server jobs. Decrypt the copied config privately; provision an operational identity that can decrypt both the fnox ciphertext and the saved encrypted password. If necessary, deliberately re-key/reseal using the retained offline identity. Never use init to replace a missing existing password. Use the encrypted capsule's `metadata.json` account/group list to recreate the named mac/service accounts before restore; their numeric IDs may differ. Leave user writers stopped, final destination trees absent, and server launchd jobs uninstalled or booted out. Do not enable normal setup's services yet.
4. Select the full snapshot ID from the independently retained recovery record; do not replace it with an ID suggested by downloaded metadata. Verify from R2 without any supervisor contact, then restore in fresh-host mode:
   ```sh
   sudo /usr/local/libexec/mac-server/backup/launch.sh verify FULL_SNAPSHOT_ID
   sudo /usr/local/libexec/mac-server/backup/launch.sh restore FULL_SNAPSHOT_ID --session reinstall-1 --offline
   ```
   Or recover from a fully downloaded iCloud repository without R2:
   ```sh
   sudo /usr/local/libexec/mac-server/backup/launch.sh verify FULL_SNAPSHOT_ID --repository /path/to/downloaded/restic-v1
   sudo /usr/local/libexec/mac-server/backup/launch.sh restore FULL_SNAPSHOT_ID --session reinstall-1 --offline --repository /path/to/downloaded/restic-v1
   ```
   The fnox age-backed profile resolves locally; a capsule or iCloud placeholders alone are not a complete restic repository. Download all receipt-listed objects first.
5. `--offline` contacts **no Pitchfork supervisor**. As root it enumerates launchd jobs and inspects their system job descriptions, refusing any mentioning Pitchfork, Forgejo, Grafana or the mac-server runtime. It also scans process command lines for those supervisor/app executables. Inspection errors are fatal. These checks repeat before installing targets and before renames. Thus a fresh host can restore without starting a supervisor that might initialize app data. This mode does not boot out jobs or kill processes; remove them through the normal security lifecycle before retrying. For an existing supervisor, omit `--offline`: both global app daemons must be explicitly stopped, and unknown status is rejected.
6. Restore verifies the downloaded snapshot against **original numeric ownership**, then resolves saved user/group **names** through current `pwd`/`grp` records. Missing names, unmapped IDs, root/non-root identity changes, or account-ID changes during a resumed session cause explicit refusal. Each copied target is content-verified before remapping, then chowned without following symlinks and mode-restored inside its root `0700` staging container. Ready/completed targets are checked against the remapped inventory on resume. Manifest schema 1 remains verifiable but lacks named-account data and is refused for installation; take a new schema-2 checkpoint before reinstalling.
7. Each target is installed with an atomic no-replace rename on its own filesystem and a durable session marker. Rerun the same snapshot/session after ordinary interruption, including between rename and marker write. This is per-target atomicity, not an all-tree transaction or a tested sudden-power-loss guarantee. Keep users from manipulating destination parents during recovery. Restore never starts/stops services, and staged plaintext remains protected by root-only ancestors.
8. After all three targets are restored, run normal setup **from the restored** `/Users/mac/Developer/configuration` checkout. Check app configuration, keys and remapped permissions before enabling jobs/services through the official security flow. Retain the private session until acceptance, then remove it and its empty adjacent containers administratively.

## Coverage and operating limits

This is application-state recovery, not a bootable disk image. State outside the listed paths (other service homes, Keychain, external symlink targets/volumes, system settings and user dotfiles) needs its own recovery plan. The copy stage does not promise macOS ACLs, resource forks or every extended attribute. Unnamed file owners and unsupported special files fail rather than being skipped. Root's scheduled runner needs Full Disk Access for private sources. Plan capacity for a full capture, two verification restores, capsule tools and an encrypted mirror; recovery needs private download plus per-target copies. There is no destructive size-cap eviction.

## Validation

Run unprivileged with restic and age/age-keygen installed (or set `TEST_RESTIC` to a trusted actual restic binary, rather than a version-manager shim):

```sh
services/backup/prune_test.sh -v
```

The task runs a restic-version preflight and fails nonzero if restic is missing or unusable. Direct `python3 services/backup/test_backup.py -v` also fails, rather than skipping integration fixtures, when required dependencies are missing. Tests use the developer Python on PATH; this does not validate the deployed protected interpreter.

Fixtures use temporary repositories, generated identities and fake service controls. They check the supervisor environment's literal required values, recovery-record hashes and unchanged snapshot stdout, and reject missing/malformed/mismatched capsule digests before staging/decryption. They exercise real restic init/backup/restore, Git/SQLite/WAL integrity, exact IDs, working/private files, service assets/keys, capsules, non-destructive courier/mirror recovery, retention, no-overwrite restore/resume, metrics, global service arguments, named-ID mapping and offline guards. Changed-ID chown is checked with mocks because fixtures deliberately run unprivileged. Courier fixtures also check numeric newest selection, unique explicit snapshots, invalid/ambiguous timestamps, single-pass selected repository hashing and preservation of historical destination files. No fixture contacts live services, cloud repositories or production secrets. Live setup/deployment, TCC and iCloud upload are not exercised by these tests.
