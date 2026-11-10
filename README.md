# Configuration

Personal macOS server, tools and dotfiles. Cloudflare Tunnels provide ingress;
Forgejo, Grafana, metrics and logs run locally. Restic writes directly to local
iCloud Drive as `mac`. There is no Python runtime, R2 backend, mirror or courier.

## Setup

Use the `mac` account at `/Users/mac`, with Command Line Tools and Homebrew.
Keep configuration at `~/Developer/configuration` and robin at `~/Developer/robin`.
Both checkouts must exist before provisioning. Recovery comes **before** setup.

```sh
cd ~/Developer/configuration
sh setup.sh --new  # explicitly create genuinely new, empty services
sh setup.sh        # configure existing or inspected/recovered service data
```

Setup is interactive and requires the matching operational age identity. A
pre-existing identity is reused, never replaced, and deployment verifies it matches
the reviewed fnox recipients. An existing encrypted Restic repository also makes
`--new` fail closed. Setup checks state before changing services; never use `--new`
to bypass a failed recovery.
Mise bootstrap installs packages, preferences and symlinks, including Delta's
instructions from `.config/delta/AGENTS.md` and `~/.config/vim/vimrc` from
`.config/vim/vimrc`.
The existing Cloudflare Tunnel, DNS and Access policies are retained.

`postinstall` calls `setup:auto`. On an established server it deploys reviewed
runtime changes, then activates them. On a fresh/partial host it only reports the
next step. `MISE_SETUP_IN_PROGRESS=1` suppresses these actions during setup and
recovery. Review changes **before** installing infrastructure tools, since an
ordinary install can restart services. Mise itself never runs under sudo.

If bootstrap reports permission errors in `~/.local/state/mise` or
`~/.config/delta`, inspect their ownership first. Previous root-run setup may
have left user state owned by root. Repair only the affected user-owned paths
with administrator approval, then retry; do not work around it by running Mise
under sudo.

For an explicit maintenance window:

```sh
MISE_SETUP_IN_PROGRESS=1 mise install
mise run updates:check
mise run daemon:install
mise run daemon:activate
```

Deployment installs protected tools/tasks and boot configuration without starting
services. `--stage` installs recovery runtime only: no boot job or logging setup.
Existing fnox configuration is preserved by default. To deliberately replace an
obsolete config, first review its encrypted service secrets, then use
`mise run daemon:install --config "$PWD/fnox.toml"`. Never replace newer secrets
blindly. The schema accepts only the fixed age-backed service profiles.

## Backup

```sh
mise run backup:run init
mise run backup:run checkpoint
mise run backup:run verify FULL_64_CHARACTER_SNAPSHOT_ID
mise run backup:run prune          # repository check and retention preview
mise run backup:run prune --apply  # explicitly apply retention/deletion
```

The same checkpoint runs daily at 03:00 through Pitchfork. Root captures
Developer, Forgejo and Grafana into private staging, pausing only previously
running applications for their local copies. Restic runs as `mac` with a temporary
private password file; the age identity stays root-only. The exact new snapshot
is restored and checked before success is published.

```text
~/Library/Mobile Documents/com~apple~CloudDocs/Backups/configuration/restic-sh-v1/
  repository/
  FULL_SNAPSHOT_ID/
    configuration.bundle
    config.toml.age
    restic-password.age
    SHA256SUMS
```

Retain the printed **snapshot ID and SHA256SUMS digest independently**, with an
offline age identity. Review configuration Git history before exporting its
unencrypted bundle. Commit this migration before making its bootstrap bundle;
uncommitted/private files are in Restic, not the Git bundle.

Initialization never replaces a password. Missing password plus a nonempty
repository, failed decryption, or an existing password with a missing repository
all cause refusal. Recover the original credentials/repository, not a new password.
Legacy repository formats/locations and stored archives are not deleted or
automatically migrated. See [backup details](services/backup/README.md).

## Recovery at ~/Developer/configuration

Materialize the **complete** iCloud folder above, including repository objects
and the artifacts for the snapshot in your independent record. An offline copy
can be used for verification/restoration with `--repository`; before resuming
backups, restore the original repository to the canonical iCloud location without
merging into or overwriting an unexplained existing repository.

Install Command Line Tools if needed (`xcode-select --install`). Verify hashes
with trusted system tools **before cloning or executing downloaded code**:

```sh
set -eu
SNAPSHOT=FULL_64_CHARACTER_SNAPSHOT_ID
SUMS_SHA256=INDEPENDENT_SHA256SUMS_DIGEST
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Backups/configuration/restic-sh-v1"
ARTIFACTS="$ICLOUD/$SNAPSHOT"
REPOSITORY="$ICLOUD/repository"
IDENTITY="/absolute/path/to/independently-retained-age-identity"

cd "$ARTIFACTS"
printf '%s  SHA256SUMS\n' "$SUMS_SHA256" | shasum -a 256 -c -
shasum -a 256 -c SHA256SUMS
mkdir -p ~/Developer
git clone "$ARTIFACTS/configuration.bundle" ~/Developer/configuration
cd ~/Developer/configuration
git checkout --detach "$(git bundle list-heads "$ARTIFACTS/configuration.bundle" HEAD | awk '{print $1}')"

curl -fsSL https://mise.run | MISE_VERSION=v2026.11.2 sh
export PATH="$HOME/.local/bin:$PATH"
mise trust
MISE_SETUP_IN_PROGRESS=1 mise install
mise run recovery:prepare --identity "$IDENTITY" \
  --password "$ARTIFACTS/restic-password.age" --config "$ARTIFACTS/config.toml.age"
mise run backup:run verify "$SNAPSHOT" --repository "$REPOSITORY"
mise run backup:run restore "$SNAPSHOT" --repository "$REPOSITORY" \
  --destination /var/db/home-backup/recovered-1
```

Inspect the private staged payload with sudo. Keep all server jobs unregistered
and applications stopped. Then explicitly install the inspected recovery:

```sh
mise run recovery:install /var/db/home-backup/recovered-1 \
  --preserve-developer /Users/mac/Developer.before-restore-1
sh ~/Developer/configuration/setup.sh
```

The installer reserves new destination directories, refuses existing service data,
and preserves the **entire old Developer tree** inside
`/Users/mac/Developer.before-restore-1/Developer`. The verified stage remains
intact. It never starts services. Installation is not an all-tree transaction:
after interruption, inspect partial destinations, preservation container and
stage; do not delete an unexplained tree merely to retry. Service ownership is
mapped to current intended accounts, not erased-host numeric IDs.

## Validation and operations

```sh
mise run test          # temporary backup/security/setup/metrics tests, then real mail
hk check --all        # configured lint, formatting and native configuration checks
mise run TASK --help
```

Mail testing intentionally submits to **both** `maclong9@icloud.com` and
`contact@maclong.dev`, configured in `vars.mail_test_recipients`. Queue submission
does not prove inbox delivery; direct Postfix delivery is intentional.

Local Restic readback is **not Apple upload confirmation**. Independently download
and verify the repository/artifacts on another machine before relying on them.
An actual erased-host rehearsal is a separate, still-required validation.
Fixtures do not establish Full Disk Access/TCC, launchd deployment, public routing,
notification delivery or physical lid behavior.

This is a dedicated server Mac: `host:server` applies always-on power settings.
Use mains power and ventilation; physically test lid close. FileVault remains
enabled and reboot/unlock attended. `git:forgejo` uses loopback SSH on port 2222
and preserves previous remotes; public clients use HTTPS. User SSH/signing keys,
Keychain, external symlink targets and iCloud documents need independent recovery.
Prometheus/Loki history starts fresh. Review version/database compatibility before
updates; only use `updates:reviewed` after completing the actual human review.

See [security boundaries](services/security/README.md).
