# Configuration

Personal macOS environment and hosted services, provisioned as one system.

## Architecture

Solid nodes are live; dashed nodes are planned. Exposure is stated on each
network-facing node.

```mermaid
flowchart TB
    Public([Public internet clients])
    Operator([Operator])
    Household([Household / Apple Home])

    subgraph External[External and network services]
        subgraph Cloudflare[Cloudflare]
            DNS[PUBLIC DNS]
            Edge[PUBLIC Tunnel edge<br/>TLS termination]
            Access[Cloudflare Access<br/>identity gate]
            Deadman[Worker + Cron + KV<br/>dead-man's switch]:::planned
        end

        GitHub[PUBLIC GitHub mirrors]
        PublicNtfy[PUBLIC ntfy.sh<br/>host-down alerts]:::planned
        APNs[Apple Push Notification service]:::planned
        Gateway[Dream Router 7<br/>VLANs + DNS filtering]:::planned
        UniFiVPN[UniFi-native private access]:::planned
        UniFiControllers[UniFi Protect + Access]:::planned
        ICloud[iCloud CalDAV<br/>Calendar + Reminders]:::planned
        ApplePasswords[Apple Passwords<br/>escrow age key]
        R2[Cloudflare R2<br/>encrypted backup]:::planned
        B2[Backblaze B2<br/>encrypted backup]:::planned
    end

    subgraph Host[MacBook Pro]
        Pitchfork[pitchfork supervisor<br/>root LaunchDaemon]
        Fnox[(fnox + operational age key)]

        subgraph CloudflaredAccount[svc_cloudflared]
            Cloudflared[cloudflared<br/>outbound connector]
        end

        subgraph CaddyAccount[svc_caddy]
            Caddy[Caddy :8080<br/>public ingress router]
            Status[PUBLIC status.maclong.dev]
        end

        subgraph ObservabilityAccount[svc_observability]
            Blackbox[LOOPBACK Blackbox :9115]
            Prometheus[LOOPBACK Prometheus :9090]
            Alloy[LOOPBACK Alloy :12345<br/>collector + scrubber]
            Loki[LOOPBACK Loki :3100]
            Grafana[ACCESS-PROTECTED dashboard.maclong.dev<br/>Grafana :3000]
        end

        subgraph ForgejoAccount[svc_forgejo]
            Forgejo[PUBLIC git.maclong.dev<br/>Forgejo :3030]
            Runner[act_runner<br/>one concurrent job]:::planned
        end

        subgraph PlannedServices[Planned services]
            Robin[PUBLIC personal site<br/>Robin]:::planned
            Ntfy[PRIVATE ntfy<br/>service alerts]:::planned
            Heartbeat[dead-man heartbeat]:::planned
            Backup[backup + archive jobs<br/>svc_backup]:::planned
            MLX[PRIVATE MLX orchestrator<br/>mlx_lm.server]:::planned
            Homebridge[PRIVATE Homebridge<br/>svc_homebridge]:::planned
            DAV[PRIVATE dav-mcp<br/>svc_household]:::planned
        end

        CaddyLog[(Caddy access log)]
        Metrics[(90-day metrics)]
        Logs[(90-day scrubbed logs)]
        ForgeData[(Forgejo repositories + SQLite)]
        LocalArchive[(local compressed archive)]:::planned
    end

    Public -->|HTTPS| DNS --> Edge
    Edge -->|status + git| Cloudflared
    Edge -->|dashboard| Access -->|authorized requests| Cloudflared
    Cloudflared -->|HTTP + Host header| Caddy
    Caddy -->|direct response| Status
    Caddy -->|reverse proxy| Forgejo
    Caddy -->|reverse proxy| Grafana
    Caddy -.->|reverse proxy| Robin

    Forgejo -->|push mirror| GitHub
    Forgejo -.->|Actions| Runner
    Forgejo --> ForgeData

    Caddy -->|JSON access log| CaddyLog --> Alloy
    Alloy -->|logs| Loki --> Logs
    Alloy -->|metrics| Prometheus --> Metrics
    Prometheus -->|probe request| Blackbox -->|HTTPS| Status
    Grafana -->|queries| Prometheus
    Grafana -->|queries| Loki

    Operator -->|authenticated HTTPS| Access
    Operator -.->|future private access| UniFiVPN -.-> Gateway -.-> Host
    Household -.->|Apple Home| Homebridge -.-> UniFiControllers
    DAV -.->|CalDAV| ICloud
    MLX -.->|tool calls| DAV

    Ntfy -.->|ordinary alerts| APNs
    Heartbeat -.->|scheduled ping| Deadman -->|stale host| PublicNtfy --> APNs

    ForgeData -.-> Backup
    Metrics -.-> Backup
    Logs -.-> Backup
    Backup -.-> LocalArchive
    LocalArchive -.->|encrypted replication| R2
    LocalArchive -.->|encrypted replication| B2

    Fnox -->|service-scoped secrets| Alloy
    Fnox -->|service-scoped secrets| Forgejo
    Fnox -.->|service-scoped secrets| PlannedServices
    ApplePasswords -.->|disaster recovery only| Fnox
    Pitchfork --> CloudflaredAccount
    Pitchfork --> CaddyAccount
    Pitchfork --> ObservabilityAccount
    Pitchfork --> ForgejoAccount
    Pitchfork -.-> PlannedServices

    classDef planned stroke-dasharray: 5 5
```

## Install

```sh
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/mac95sb/configuration/main/setup.sh)"
```
