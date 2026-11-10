# Restic backup and recovery

Restic's sole repository is on the Mac's local iCloud Drive:
`~/Library/Mobile Documents/com~apple~CloudDocs/Backups/configuration/recovery-v1/restic-v1`.
The backup process writes the encrypted Restic repository and recovery artifacts
directly into that directory. There is no R2 destination or courier. Files being
present locally does not prove that iCloud has finished syncing them.

## Runtime and credentials

`services/security` provisions the protected root runtime. Its installed entry
point is `/usr/local/libexec/mac-server/backup/launch.sh`. Root is required for
reading the private sources, controlling Forgejo, and restoring original file
owners. The Restic repository and artifacts are under the signed-in `mac` user's
iCloud Drive; the host must have iCloud Drive enabled and the root backup process
must have access to that path.

Restic uses a generated password encrypted to the operational age identity. It
receives the password through `RESTIC_PASSWORD_COMMAND`; it is not put in argv or
written in plaintext during backup/restore. The offline recovery identity and the
independently retained `OFFLINE_RECOVERY_RECORD` are required for clean-machine
recovery. The record pins the capsule, configuration bundle and receipt hashes.

## Capture and consistency

The payload contains:

- `/Users/mac/Developer`, including hidden, ignored, untracked and private files.
  `node_modules`, `.build`, `__pycache__`, `.cache` and `Caches` are excluded.
- Configuration and robin Git bundles and their exact HEADs.
- The Forgejo data tree, including its database, repositories, assets and keys.
- Grafana's data tree and database.

Forgejo is paused briefly while its database and associated repository files are
copied; previously stopped services remain stopped. Grafana stays online: its
database copy is made with SQLite's online backup API so committed WAL data is
included consistently. Services resume before Restic encryption and verification.
The Developer tree is copied file by file, not as an APFS point-in-time snapshot;
the coordinator checks the Git HEAD before and after capture and fails if it
changed. Avoid editing other Developer files during a capture.

The coordinator restores and validates the exact new snapshot before reporting
success. It checks the payload manifest, Git bundles and repository integrity,
and both SQLite databases. Checkpoint also requires clean configuration and robin
checkouts.

## Commands

```sh
mise run recovery:init
mise run recovery:checkpoint
mise run recovery:verify FULL_64_CHARACTER_SNAPSHOT_ID
mise run recovery:prune
mise run recovery:prune --apply
```

Normal scheduled backups do not prune. Pruning is a dry run unless `--apply` is
given; it retains latest 1, daily 7, weekly 5 and monthly 12 snapshots for
`home-mac`/`home-v1`. The coordinator lock serializes backup, restore and prune
operations on this Mac.

Backup and checkpoint print the actual Restic snapshot ID to stdout and an
`OFFLINE_RECOVERY_RECORD` JSON line to stderr. Keep that record independently
with the offline age identity. Do not trust a receipt or hash downloaded from the
same iCloud account as the only integrity reference.

## Clean-machine recovery

1. Keep the offline age identity and trusted recovery record separate from the
   Mac. Sign in to the iCloud account and fully download/materialize the backup
   directory, including all files under `restic-v1`.
2. Verify the downloaded configuration bundle against the independently kept
   SHA-256 before cloning or executing any recovered code.
3. Run `sh setup.sh --recover` from a trusted checkout outside `~/Developer`.
   It prompts for the independently retained record and age identity; the capsule
   contains encrypted configuration and the Restic password, not an age identity.
4. Provision required user and service accounts, install the protected runtime,
   and verify/restore from the downloaded local repository:

   ```sh
   sudo /usr/local/libexec/mac-server/backup/launch.sh verify FULL_SNAPSHOT_ID \
     --repository "/Users/mac/Library/Mobile Documents/com~apple~CloudDocs/Backups/configuration/recovery-v1/restic-v1"
   sudo /usr/local/libexec/mac-server/backup/launch.sh restore FULL_SNAPSHOT_ID \
     --session reinstall-1 --offline \
     --repository "/Users/mac/Library/Mobile Documents/com~apple~CloudDocs/Backups/configuration/recovery-v1/restic-v1"
   ```

`--offline` refuses to restore while server launchd jobs or relevant processes are
present. Restore refuses existing destination trees, stages and verifies each
target before an atomic no-replace rename, and remaps saved account names to the
accounts on the recovered Mac.

## Validation

Run the local fixture suite as an unprivileged user with Restic and age installed:

```sh
services/backup/prune_test.sh -v
```

Fixtures use temporary repositories, generated identities and fake service
controls. They do not contact iCloud or production services and do not establish
that a live iCloud sync has completed.
