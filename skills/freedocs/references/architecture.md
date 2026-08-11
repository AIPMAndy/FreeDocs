# Architecture

## Default topology

```text
Browser
  |
  | HTTPS
  v
Nginx
  |-- /freedocs-assets/* --> MinIO :31900
  |-- /dex/*             --> Dex   :5556
  `-- /*                 --> Outline:3100
                              |-- PostgreSQL
                              |-- Redis
                              `-- MinIO (internal S3 endpoint)
```

All published application ports bind to `127.0.0.1`. Only Nginx exposes 80/443.

## Component roles

| Component | Role | Source of truth |
|---|---|---|
| Outline | Editing, collections, search, member permissions, public shares | No |
| PostgreSQL | Document metadata and application state | Runtime truth |
| Redis | Cache and jobs | Rebuildable runtime state |
| MinIO/S3 | Images and attachments | Runtime truth |
| Dex | Small-installation OIDC login | Authentication config |
| Nginx | HTTPS and same-origin routing | Public entrypoint |
| Markdown/JSON export | Vendor-independent readable copy | Recovery/export layer |
| Encrypted backup | Database, objects, configuration, exports | Disaster-recovery truth |

## Important boundaries

- Self-hosting reduces platform-account lockout risk; it does not remove operational, security, hardware, or cloud-account risk.
- Outline is source-available under BSL 1.1, not an MIT-style permissive project. FreeDocs does not redistribute Outline; it orchestrates official images. Re-check the current Outline license before offering hosted workspaces to third parties.
- Public shares and authenticated collaboration are separate. Anonymous comments are not part of the default promise.
- A single-server backup is not an offsite backup. A backup in the same cloud account does not cover account-level lockout.

## Adaptation rules

- Reuse an existing managed PostgreSQL, Redis, S3, OIDC, or reverse proxy when it is already secure and supported.
- Use unique ports, networks, database names, buckets, and OIDC clients for parallel environments.
- Keep the public object upload URL HTTPS-reachable from the browser. The internal S3 endpoint may remain `http://minio:9000` only for server-to-server access.
- Pin versions and rehearse upgrades against a restored copy before production.
