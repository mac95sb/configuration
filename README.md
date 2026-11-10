# Configuration

macOS workstation and server configuration, managed with Mise.

## Set up

For a fresh system, run from a trusted checkout:

```sh
sh setup.sh
```

To restore an existing system:

1. Sign in to the Mac with the iCloud account that holds the backup.
2. From the independently saved `OFFLINE_RECOVERY_RECORD`, find the
   `bootstrap_bundle` filename and SHA-256. Set `bundle` to its iCloud Drive
   path, replacing `FILENAME` with that filename:

   ```sh
   bundle="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Backups/configuration/recovery-v1/FILENAME"
   shasum -a 256 "$bundle"
   ```

   Compare the output with the saved SHA-256. Stop if they differ or the file
   is unavailable.
3. Clone the verified bundle **outside** `~/Developer`, then run recovery:

   ```sh
   git clone "$bundle" /tmp/configuration-recovery
   cd /tmp/configuration-recovery
   sh setup.sh --recover
   ```

The current recovery task refuses an existing `~/Developer` and restores that
directory, including `~/Developer/configuration`, from the Restic snapshot.
Do not create it or clone the bundle there before recovery.

Recovery prompts separately for the complete `OFFLINE_RECOVERY_RECORD` line and
the offline age secret key (`AGE-SECRET-KEY-...`). Paste each from your password
manager at its prompt. They are two different values.
Keep both separately from the Mac and iCloud Drive. Recovery has not yet been
rehearsed on an erased host; verify that the files have synced to iCloud and
test restoration before relying on them for a reset.

## Update and maintain

```sh
mise install                 # Install tools and run the setup/update hook
mise run updates:check       # Check installed Forgejo and Grafana versions
mise run updates:reviewed    # Record a completed update review
mise run test                # Run Restic and outbound-mail smoke tests
```

`mise install` may restart services when infrastructure tools change. Review
database compatibility and create a recovery checkpoint before upgrading Forgejo
or Grafana.

## Backup and recovery

Restic stores encrypted backups under
`~/Library/Mobile Documents/com~apple~CloudDocs/Backups/configuration/recovery-v1/`.

```sh
mise run recovery:checkpoint
mise run recovery:verify SNAPSHOT_ID
mise run recovery:prune        # Preview retention
mise run recovery:prune --apply
```

Save the `OFFLINE_RECOVERY_RECORD` printed by a checkpoint with the offline age
identity. See [backup instructions](services/backup/README.md) for coverage,
recovery prerequisites and limitations.

The configured schedule runs a backup daily at 03:00 local time, not the
manual checkpoint command. Run a checkpoint yourself when you need its recovery
record.

## Other tasks

```sh
mise tasks ls                # List available tasks
mise run host:server         # Disable sleep for server use
mise run host:portable       # Re-enable sleep for portable use
mise run git:forgejo         # Configure Forgejo remotes
```

>[!NOTE]
> Use mains power and ventilation in server mode, and test lid behavior on the actual Mac. FileVault still requires an attended unlock after reboot.