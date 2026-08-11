#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$root_dir/.env"
failed=0

file_mode() {
  if stat -c '%a' "$1" >/dev/null 2>&1; then
    stat -c '%a' "$1"
  else
    stat -f '%Lp' "$1"
  fi
}

for command_name in docker jq openssl sed stat curl; do
  if command -v "$command_name" >/dev/null; then
    echo "PASS command: $command_name"
  else
    echo "FAIL missing command: $command_name"
    failed=1
  fi
done

if command -v docker >/dev/null && ! docker compose version >/dev/null 2>&1; then
  echo "FAIL Docker Compose plugin is unavailable"
  failed=1
fi

if [[ ! -f "$env_file" ]]; then
  echo "FAIL missing .env; run scripts/prepare.sh"
  failed=1
elif grep -q '=GENERATE_ME$' "$env_file"; then
  echo "FAIL .env still contains placeholders"
  failed=1
elif [[ "$(file_mode "$env_file")" != "600" ]]; then
  echo "FAIL .env must use mode 600"
  failed=1
else
  echo "PASS generated .env and permissions"
fi

if [[ -f "$env_file" ]] && ! grep -Eq '^DEX_STATIC_PASSWORD_HASH=\$\$2[aby]\$\$[0-9]{2}\$\$' "$env_file"; then
  echo "FAIL Dex bcrypt hash is not escaped for Compose interpolation"
  failed=1
else
  echo "PASS Dex bcrypt hash format"
fi

if grep -Eq '(^|:)latest($|[[:space:]])' "$root_dir/compose.yaml" "$root_dir/.env.example"; then
  echo "FAIL mutable latest image tag found"
  failed=1
else
  echo "PASS pinned image tags"
fi

if [[ $failed -ne 0 ]]; then
  exit 1
fi

compose=(docker compose --env-file "$env_file" -f "$root_dir/compose.yaml")
"${compose[@]}" config --quiet
config_json=$("${compose[@]}" config --format json)

if ! jq -e '[.services[] | (.ports // [])[] | .host_ip] | all(. == "127.0.0.1")' >/dev/null <<<"$config_json"; then
  echo "FAIL one or more published service ports are not loopback-only"
  exit 1
fi

if ! jq -e '.services.postgres.ports == null and .services.redis.ports == null' >/dev/null <<<"$config_json"; then
  echo "FAIL PostgreSQL or Redis is published to the host"
  exit 1
fi

if grep -Eq '^AWS_S3_UPLOAD_BUCKET_URL=http://(minio|[^/]*:9000)' "$env_file"; then
  echo "FAIL browser upload URL uses an internal MinIO address"
  exit 1
fi

echo "PASS Compose configuration"
echo "PASS published service ports are loopback-only"
echo "PASS browser upload URL is not container-internal"
echo "Preflight does not prove login, import, search, sharing, or recovery."
