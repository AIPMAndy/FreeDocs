---
name: freedocs
description: Build, migrate, secure, and verify a self-hosted Outline knowledge base that acts as a controllable Feishu/Lark Wiki alternative. Use when a user asks to deploy a private knowledge base on their own Linux server, migrate DOCX exports, configure Outline with PostgreSQL, Redis, MinIO, Dex, Nginx, HTTPS, sharing or collaboration, or prove backup and recovery readiness. Also use to diagnose failed uploads, internal MinIO URLs, login issues, duplicate imports, public-share permissions, or a deployment that is healthy but not actually usable.
---

# FreeDocs

Build a usable, shareable, and recoverable Outline knowledge base without treating container health as completion. Keep the user's source exports untouched and make every success claim evidence-based.

## Load the right resources

- Read [references/architecture.md](references/architecture.md) before choosing or changing the topology.
- Read [references/deployment.md](references/deployment.md) for a new server, reverse proxy, TLS, OIDC, or object-storage setup.
- Read [references/migration.md](references/migration.md) before uploading DOCX files or changing collection structure.
- Read [references/acceptance.md](references/acceptance.md) before reporting completion.
- Read [references/backup-restore.md](references/backup-restore.md) before claiming that the data is recoverable.
- Start from [assets/freedocs-stack](assets/freedocs-stack) for a new Docker Compose deployment. Copy it into a user-approved working directory; never edit the installed Skill in place for a production deployment.
- Use the bundled `scripts/backup.sh` and `scripts/restore-files.sh` for the default Restic file-level workflow, then complete the isolated application restore in [references/backup-restore.md](references/backup-restore.md).

## Operating contract

1. Treat the original Feishu/Lark export directory as read-only. Never move, rename, overwrite, or delete source files.
2. Inspect the server, DNS, existing reverse proxy, open ports, Docker, storage, memory, and backups before changing anything.
3. Ask for confirmation before DNS changes, firewall changes, public exposure, document upload, permission changes, account creation, or destructive cleanup. Let the user enter passwords, OTPs, API keys, and private credentials directly; never echo them into chat or logs.
4. Back up every file that will be changed. Pin container versions; never deploy `latest`.
5. Keep PostgreSQL and Redis off public interfaces. Bind application, Dex, and MinIO ports to loopback unless the existing architecture provides an equally restrictive private network.
6. Keep the S3 service endpoint internal for server-to-server calls, but make browser uploads use a public HTTPS URL. Never return `http://minio:9000` or another container-only address to the browser.
7. Separate three states in every report: infrastructure health, authenticated product usability, and content-migration acceptance.
8. Do not promise anonymous comments. Verify public reading, member editing, and comments as separate permission paths with real test accounts.
9. Do not call a backup complete until a fresh restore has been performed and checked.
10. Make the smallest change compatible with the user's existing server. Do not replace a working proxy, identity provider, database, or object store merely to match the bundled template.

## Workflow

### 1. Discover and classify

Collect or discover:

- target domain and DNS ownership;
- Linux distribution, CPU architecture, RAM, disk, swap, and free space;
- Docker Engine and Compose versions;
- existing Nginx/Caddy/Traefik configuration and ports 80/443;
- desired owner email and login provider;
- source document directory and approved migration scope;
- sharing model: private members, public read links, or both;
- backup destination outside the primary server/account.

Choose one mode:

- **Fresh server:** use the bundled stack and host Nginx template.
- **Existing server:** preserve the current proxy and allocate unused loopback ports.
- **Existing Outline:** diagnose and repair only the failing layer; do not redeploy the stack by default.

Give a short plan, exact targets, rollback path, and user-held actions before mutation.

### 2. Stage safely

Copy `assets/freedocs-stack/` to a user-approved server directory such as `/opt/freedocs`. Run `scripts/prepare.sh` there to generate `.env` and `nginx/freedocs.conf` locally. Do not commit either generated file.

Before startup:

```bash
./scripts/preflight.sh
docker compose --env-file .env -f compose.yaml config --quiet
```

If the server already hosts applications, verify port and resource conflicts first. Back up any Nginx file before installing or replacing it.

### 3. Deploy in layers

Bring up PostgreSQL, Redis, MinIO, MinIO bootstrap, Dex, then Outline. Configure Nginx and TLS only after loopback services pass their checks. Use [references/deployment.md](references/deployment.md) for the exact order.

After every configuration change:

- validate syntax;
- restart only the affected service;
- verify its state and logs;
- verify the public route from outside the container network.

### 4. Prove one complete document path

Do not batch-import first. With explicit approval, import one representative DOCX containing long text, headings, images, tables, and links. Verify:

- a document record was created;
- title and body are readable;
- images and attachments load through public HTTPS;
- title and body text are searchable;
- the document is in the expected collection;
- a public share opens in a signed-out browser if public reading is intended;
- private siblings and internal comments do not leak.

If upload fails before the response, inspect the presigned upload URL first. A container-only MinIO hostname is a routing bug, not a DOCX problem.

### 5. Migrate with a ledger

Inventory approved files with relative path, size, and SHA-256. Import in small batches. Record every source file, resulting document URL/ID, search result, media status, and suspected duplicate. Stop on unexplained count drift or repeated timeouts. Never auto-delete same-title documents.

### 6. Verify collaboration and publishing

Test with at least two identities when collaboration is required:

- owner/admin;
- member/editor or viewer;
- signed-out browser for public links.

Treat collection URLs, document URLs, and public share URLs as different products. Link a public website only to the intended destination, then verify desktop and mobile rendered links instead of trusting source files or build output.

### 7. Back up and restore

Back up PostgreSQL, object storage, the generated `.env`, Dex configuration, reverse-proxy configuration, and Outline Markdown/JSON exports into an encrypted repository. Keep at least one copy outside the primary server and, for account-lockout resilience, outside the primary cloud account.

Run a restore drill into new volumes or a new host. Check document count, selected document IDs, media, search, permissions, and hashes. Keep restore evidence and elapsed time.

### 8. Report with gates

Use this status model:

- `INFRASTRUCTURE_READY`: services and routes are healthy; login/import may still be unverified.
- `PRODUCT_READY`: login, editing, search, and one representative import passed.
- `MIGRATION_READY`: every approved source item has a reconciled ledger result.
- `SHARING_READY`: intended member/public permission paths passed real-browser tests.
- `RECOVERY_READY`: encrypted backup and fresh restore drill passed.
- `COMPLETE`: all user-requested gates above are satisfied with evidence.

Never collapse partial states into “上线完成”. Report blockers, evidence, rollback location, and remaining risks concisely.

## Failure patterns

- Healthy containers but failed imports: check the browser-visible S3 URL and Nginx bucket route.
- Login loop or invalid account: verify Dex issuer, callback URL, client secret, bcrypt escaping, and the full restart/login chain.
- Source changed but mobile still links elsewhere: inspect served client assets and actual rendered hrefs; do not widen the fix to unrelated build failures.
- Import count exceeds source count: freeze uploads, reconcile the ledger, compare content, and leave duplicates untouched until a human decides.
- Public page asks for login: confirm the user copied a public share URL rather than a private document or collection URL.
- Backup exists but cannot restore: mark recovery as failed; repair the restore path before importing more critical data.

## Completion output

Return:

1. final status by gate;
2. public and private URLs without secrets;
3. service and browser evidence;
4. migration totals and unresolved duplicates;
5. backup location class and restore evidence;
6. rollback path;
7. remaining risks and exact user-held actions.
