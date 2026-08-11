# Backup and restore

## Backup set

Include:

1. PostgreSQL custom-format dump;
2. MinIO/S3 current objects and an object inventory;
3. Outline Markdown and JSON exports when available;
4. `.env`, Dex configuration, reverse-proxy configuration, Compose files, and pinned image references;
5. a SHA-256 manifest and timestamped metadata.

Encrypt the set before it leaves the server. Keep the repository password outside the server and outside the cloud account that hosts the primary service.

## Bundled Restic workflow

The fresh-server asset includes `scripts/backup.sh` and `scripts/restore-files.sh`. Use a dedicated encrypted Restic repository. Provide credentials through Restic's supported environment or configuration files; do not edit credentials into either script.

Before backup, create a fresh Outline Markdown/JSON export and set its directory:

```bash
export RESTIC_REPOSITORY=/approved/offsite/repository
export RESTIC_PASSWORD_FILE=/approved/secret/location/restic-password
export FREEDOCS_EXPORT_DIR=/approved/outline-export
./scripts/backup.sh
```

The script creates a custom-format PostgreSQL dump, validates its table of contents, mirrors MinIO objects, records an object inventory, copies generated configuration, adds optional readable exports, writes a SHA-256 manifest, creates an encrypted Restic snapshot, and runs `restic check`. Its unencrypted staging directory is removed on exit.

Restore files only into a new path:

```bash
./scripts/restore-files.sh latest /approved/new/restore-drill-2026-08-11
```

The restore script refuses existing or broad target paths and verifies the SHA-256 manifest. This proves file-level recovery only. It deliberately does not overwrite a production database or object bucket.

## Copies

- Local encrypted repository: useful for accidental deletion; not enough for server loss.
- Offsite encrypted repository: covers server/disk loss.
- Different-account or different-provider copy: covers cloud-account lockout.

Use least-privilege credentials dedicated to the backup destination. Never embed credentials in repository URLs, Git, Compose, reports, or command-line arguments.

## Restore drill

Restore into a fresh host or a distinct Compose project with new volumes and unused loopback ports:

1. restore and verify the manifest;
2. validate the PostgreSQL dump with `pg_restore --list`;
3. import into an empty PostgreSQL database;
4. restore objects into an empty bucket;
5. start the pinned Outline version with restored secrets and configuration;
6. check document count and selected document IDs;
7. open representative documents and media;
8. verify search, owner login, member permissions, and one public share;
9. record start/end time, errors, RPO/RTO, and cleanup/retention decision.

Do not destroy the restore environment until the owner accepts the evidence. Do not use production volumes as a restore target.

For the application-level drill, copy the restored configuration into a separate deployment directory, select a distinct Compose project and unused loopback ports, start empty PostgreSQL and MinIO storage, then import `postgres.dump` and the restored objects. Perform those mutations only after confirming the isolated target. Keep production volumes and buckets entirely out of the command path.

## Honest status

- Snapshot uploaded: backup transport passed.
- Snapshot integrity checked: encrypted repository passed.
- Files restored: file-level recovery passed.
- Services started with restored data: application recovery passed.
- Browser acceptance passed: recovery readiness passed.

Only the final state justifies `RECOVERY_READY`.
