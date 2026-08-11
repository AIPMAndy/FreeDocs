# Deployment runbook

## Contents

1. Prerequisites
2. Fresh-server order
3. Reverse proxy and TLS
4. OIDC login
5. Object upload routing
6. Update procedure

## 1. Prerequisites

- Linux server with a supported Docker Engine and Compose plugin.
- A domain whose A/AAAA records resolve to the server.
- Ports 80 and 443 reachable.
- Enough disk for database, object storage, exports, and at least one temporary backup; size from the source corpus instead of assuming a universal minimum.
- `bash`, `curl`, `jq`, `openssl`, `sed`, `stat`, and either `htpasswd` or Docker.
- A second storage/account destination for encrypted backups.

Record CPU, RAM, swap, disk, architecture, OS, proxy, listening ports, DNS, and certificate state before changes.

## 2. Fresh-server order

1. Copy `assets/freedocs-stack` into an approved directory.
2. Run `./scripts/prepare.sh`; enter the domain, owner email, and password interactively.
3. Run `./scripts/preflight.sh`.
4. Pull pinned images.
5. Start `postgres redis minio minio-bootstrap dex outline`.
6. Confirm loopback health and inspect logs.
7. Install the generated Nginx configuration after backing up any existing target.
8. Obtain or attach a valid TLS certificate.
9. Run `nginx -t`, reload Nginx, then run `./scripts/healthcheck.sh`.
10. Complete browser login and the one-document acceptance test.

Example commands after review:

```bash
docker compose --env-file .env -f compose.yaml pull
docker compose --env-file .env -f compose.yaml up -d
docker compose --env-file .env -f compose.yaml ps
```

Do not paste `.env` or credential-bearing commands into chat.

## 3. Reverse proxy and TLS

The generated Nginx file contains three routes:

- the bucket prefix to MinIO;
- `/dex/` to Dex;
- everything else to Outline.

The bucket route must appear before the Outline catch-all route. Preserve WebSocket upgrade headers. Validate before reload:

```bash
nginx -t
systemctl reload nginx
```

Use the server's existing certificate workflow. If Certbot is chosen, obtain the certificate only after DNS points to the server and the user approves public exposure.

## 4. OIDC login

Dex uses a local static password only as the small-installation default. For larger teams, replace it with a maintained OIDC provider.

Verify:

- issuer is the public `https://DOMAIN/dex` URL;
- callback is `https://DOMAIN/auth/oidc.callback`;
- client IDs and secrets match;
- the bcrypt hash reaches Dex with single-dollar separators after Compose interpolation;
- no plaintext password is stored;
- login works after an actual Dex restart.

## 5. Object upload routing

Outline uses the internal endpoint for server operations and the public endpoint for browser uploads:

```text
AWS_S3_UPLOAD_BUCKET_URL=https://DOMAIN
AWS_S3_UPLOAD_BUCKET_NAME=freedocs-assets
```

With path-style S3, browser requests begin with `/freedocs-assets/`; Nginx proxies that prefix to loopback MinIO without removing the bucket name.

If an upload creates an attachment record but no document, inspect the browser network request. A URL containing `http://minio:9000` cannot be reached by the user's browser.

## 6. Update procedure

1. Read upstream release notes and license changes.
2. Create and verify a fresh backup.
3. Restore it into an isolated rehearsal stack.
4. Run the new Outline image against the copy.
5. Verify counts, representative documents, search, media, permissions, and public links.
6. Schedule the production update with rollback images and database backup retained.
7. Never auto-follow `latest`.
