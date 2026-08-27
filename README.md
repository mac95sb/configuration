# Configuration
Personal macOS environment and hosted services, provisioned as one system.

## Install
Recover the most recent configuration bundle from a backup store, clone it, then run
the installer from that clone. Nothing runs out of iCloud Drive; the bundle is only
the source of the clone.

```sh
bundle="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Backups/configuration/configuration-latest.bundle"
brctl download "$bundle"
git clone "$bundle" "$HOME/Developer/configuration"
sh "$HOME/Developer/configuration/setup.sh"
```

`brctl download` materialises the bundle, which iCloud Drive may hold as a
placeholder. Cloudflare R2 carries the same bundles if iCloud is unreachable.

## Backup and recovery

The backup daemon runs at 03:00 daily. It keeps encrypted dailies, promotes
Sundays to weeklies and the last Sunday of each month to monthlies, then copies
the same 8.5 GB tier-aware rolling set to Cloudflare R2 and iCloud Drive.

Immediately before erasing the host, commit the configuration and Robin checkouts and
create a verified recovery point:

```sh
mise run recovery:checkpoint
```

The checkpoint refuses a dirty checkout, backs up the current service state, verifies
the configuration bundle contains `main`, downloads and validates the encrypted R2
archive, then couriers the same files to iCloud Drive.

Application data, service configuration and repositories normally have a 24-hour RPO
and four-hour RTO; a pre-reset checkpoint reduces the planned-reset RPO to zero. During
setup, paste the operational age key when prompted. The installer downloads and
validates the newest R2 archive, restores Forgejo and Grafana before starting them, and
reuses the encrypted Cloudflare tunnel credential. DNS routes and the Access policy stay
in the Cloudflare account. Prometheus metrics and Loki logs deliberately start with new
histories.

There is no live storage redundancy. Reconsider the design when free space falls below
100 GiB, is projected to do so within 12 months, a second always-on host needs shared
writable data, or a service needs an RTO below four hours. Applications with external
users move to managed hosting before storing user data.

On 27 August 2026 an R2 restore verified both SQLite databases, both Git
bundles and both Forgejo repositories. Grafana then started from the restored
database on a clean temporary path and reported `database: ok`. Repeat the
drill annually and after any material backup change.

## Architecture
```mermaid
flowchart LR
    Internet([Internet]) --> Cloudflare[Cloudflare<br/>DNS, TLS, dashboard access]

    subgraph Host[MacBook Pro]
        Cloudflared[cloudflared] --> Caddy[Caddy :8080]
        Caddy --> Status[status]
        Caddy --> Forgejo[Forgejo :3030]
        Caddy --> Grafana[Grafana :3000]
        Observability[Prometheus, Loki,<br/>Alloy, Blackbox] --> Grafana
    end

    Cloudflare -->|outbound tunnel| Cloudflared
```

- `pitchfork` starts every daemon at boot.
- Daemons run under isolated service accounts; backends listen only on loopback.
- `fnox` decrypts service-scoped secrets at runtime.
- Observability data stays local.
