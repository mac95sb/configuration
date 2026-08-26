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
