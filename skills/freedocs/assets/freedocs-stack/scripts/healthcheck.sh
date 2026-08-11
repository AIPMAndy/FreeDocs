#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$root_dir/.env"
[[ -f "$env_file" ]] || { echo "Missing .env" >&2; exit 1; }

read_env() {
  sed -n "s/^$1=//p" "$env_file" | tail -n 1
}

url=$(read_env URL)
minio_port=$(read_env MINIO_API_HOST_PORT)
compose=(docker compose --env-file "$env_file" -f "$root_dir/compose.yaml")

running=$("${compose[@]}" ps --status running --services)
for service in outline postgres redis minio dex; do
  grep -qx "$service" <<<"$running" || {
    echo "FAIL service is not running: $service" >&2
    exit 1
  }
  echo "PASS running: $service"
done

curl -fsS --max-time 15 "http://127.0.0.1:${minio_port}/minio/health/live" >/dev/null
echo "PASS MinIO loopback health"

public_code=$(curl -LsS -o /dev/null -w '%{http_code}' --max-time 20 "$url")
case "$public_code" in
  200|301|302) echo "PASS public Outline route: HTTP $public_code" ;;
  *) echo "FAIL public Outline route: HTTP $public_code" >&2; exit 1 ;;
esac

curl -fsS --max-time 20 "$url/dex/.well-known/openid-configuration" >/dev/null
echo "PASS public Dex discovery"
echo "Health checks do not prove login, DOCX import, search, sharing, or recovery."
