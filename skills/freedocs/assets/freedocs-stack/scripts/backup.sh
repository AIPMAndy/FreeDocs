#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$root_dir/.env"

fail() {
  echo "FAIL $*" >&2
  exit 1
}

[[ -f "$env_file" ]] || fail "missing .env"
command -v docker >/dev/null || fail "docker is required"
command -v restic >/dev/null || fail "restic is required"
command -v sha256sum >/dev/null || fail "sha256sum is required"
[[ -n "${RESTIC_REPOSITORY:-}" ]] || fail "RESTIC_REPOSITORY is required"
if [[ -z "${RESTIC_PASSWORD_FILE:-}" && -z "${RESTIC_PASSWORD_COMMAND:-}" ]]; then
  fail "set RESTIC_PASSWORD_FILE or RESTIC_PASSWORD_COMMAND; do not put the password in this script"
fi

read_env() {
  sed -n "s/^$1=//p" "$env_file" | tail -n 1
}

postgres_user=$(read_env POSTGRES_USER)
postgres_db=$(read_env POSTGRES_DB)
bucket=$(read_env AWS_S3_UPLOAD_BUCKET_NAME)
[[ -n "$postgres_user" && -n "$postgres_db" && -n "$bucket" ]] || fail "required .env values are missing"

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
stage_name="backup-staging-$timestamp"
stage="$root_dir/runtime/$stage_name"
mkdir -p "$stage/config" "$stage/objects" "$stage/exports"
chmod 700 "$root_dir/runtime" "$stage"

cleanup() {
  if [[ -d "$stage" && "$stage" == "$root_dir"/runtime/backup-staging-* ]]; then
    rm -rf -- "$stage"
  fi
}
trap cleanup EXIT

compose=(docker compose --env-file "$env_file" -f "$root_dir/compose.yaml")

echo "Creating PostgreSQL dump"
"${compose[@]}" exec -T postgres pg_dump -Fc -U "$postgres_user" "$postgres_db" > "$stage/postgres.dump"
"${compose[@]}" exec -T postgres pg_restore --list < "$stage/postgres.dump" >/dev/null

echo "Copying MinIO objects and inventory"
"${compose[@]}" run --rm --no-deps mc mirror --overwrite \
  "freedocs/$bucket" "/runtime/$stage_name/objects"
"${compose[@]}" run --rm --no-deps mc ls --recursive --json \
  "freedocs/$bucket" > "$stage/object-inventory.jsonl"

cp -p "$env_file" "$stage/config/.env"
cp -p "$root_dir/compose.yaml" "$stage/config/compose.yaml"
cp -p "$root_dir/.env.example" "$stage/config/.env.example"
cp -R "$root_dir/dex" "$stage/config/dex"
cp -R "$root_dir/minio" "$stage/config/minio"
cp -R "$root_dir/nginx" "$stage/config/nginx"
chmod 600 "$stage/config/.env"

export_status="MISSING"
if [[ -n "${FREEDOCS_EXPORT_DIR:-}" ]]; then
  export_source=$(cd "$FREEDOCS_EXPORT_DIR" 2>/dev/null && pwd) || fail "FREEDOCS_EXPORT_DIR is not readable"
  [[ "$export_source" != "$stage" && "$export_source" != "$stage"/* ]] || fail "export directory cannot be inside backup staging"
  cp -R "$export_source"/. "$stage/exports/"
  export_status="INCLUDED"
else
  echo "WARN FREEDOCS_EXPORT_DIR is not set; Markdown/JSON exports are not included" >&2
fi

cat > "$stage/metadata.txt" <<EOF
created_utc=$timestamp
backup_format=freedocs-v1
postgres_database=$postgres_db
object_bucket=$bucket
outline_exports=$export_status
EOF

(
  cd "$stage"
  find . -type f ! -name manifest.sha256 -print0 \
    | sort -z \
    | xargs -0 sha256sum > manifest.sha256
)

echo "Writing encrypted Restic snapshot"
(
  cd "$stage"
  restic backup . --tag freedocs --tag "$timestamp"
)
restic check

echo "PASS encrypted snapshot created and repository structure checked"
echo "Snapshot timestamp: $timestamp"
if [[ "$export_status" != "INCLUDED" ]]; then
  echo "Status is not RECOVERY_READY until readable exports and a fresh application restore pass." >&2
else
  echo "A backup is not RECOVERY_READY until a fresh application restore and browser acceptance pass."
fi
