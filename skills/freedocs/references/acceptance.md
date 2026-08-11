# Acceptance gates

Every checked item needs a date and a command, screenshot, URL, report, or file path. Unverified items remain open.

## Infrastructure

- [ ] Images are pinned; no `latest` tags.
- [ ] `.env` exists only on the server, is mode `600`, and is excluded from Git.
- [ ] PostgreSQL and Redis have no public host ports.
- [ ] All application ports except 80/443 bind to loopback or a private network.
- [ ] Nginx configuration passes validation and public HTTPS works.
- [ ] Outline, PostgreSQL, Redis, MinIO, and Dex are healthy.

## Product

- [ ] Owner can log in through the intended public domain.
- [ ] Owner can create, edit, and search a document.
- [ ] A representative DOCX creates a real document.
- [ ] Representative text, images, tables, and links are checked.
- [ ] Browser uploads use public HTTPS, not a Docker-internal hostname.

## Migration

- [ ] Approved-source inventory includes path, size, and SHA-256.
- [ ] Every approved source has a resulting URL/ID or documented failure.
- [ ] Every successful import is searchable.
- [ ] Count reconciliation has no unexplained drift.
- [ ] Suspected duplicates have human decisions; no automatic deletion occurred.

## Sharing and collaboration

- [ ] Owner, member/viewer, and signed-out paths were tested separately.
- [ ] Intended public share opens signed out.
- [ ] Private content and internal comments do not leak publicly.
- [ ] Editing/comment permissions were tested with a second account if promised.
- [ ] Website navigation, if changed, was clicked on desktop and mobile.

## Recovery

- [ ] PostgreSQL dump is readable by `pg_restore --list`.
- [ ] Current object-storage data and inventory are included.
- [ ] Generated configuration and encrypted secrets are recoverable.
- [ ] Markdown or JSON export is included and readable without Outline.
- [ ] Encrypted backup exists outside the primary server.
- [ ] At least one copy is outside the primary cloud account when account lockout is in scope.
- [ ] A fresh restore into new storage/volumes passed.
- [ ] Restored document count, sample IDs, media, search, and permissions match.

Only report `COMPLETE` when all gates required by the user's scope pass.
