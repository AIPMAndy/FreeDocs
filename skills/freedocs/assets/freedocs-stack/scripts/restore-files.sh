#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "FAIL $*" >&2
  exit 1
}

command -v restic >/dev/null || fail "restic is required"
command -v sha256sum >/dev/null || fail "sha256sum is required"
[[ -n "${RESTIC_REPOSITORY:-}" ]] || fail "RESTIC_REPOSITORY is required"
if [[ -z "${RESTIC_PASSWORD_FILE:-}" && -z "${RESTIC_PASSWORD_COMMAND:-}" ]]; then
  fail "set RESTIC_PASSWORD_FILE or RESTIC_PASSWORD_COMMAND"
fi

snapshot=${1:-latest}
target=${2:-}
[[ -n "$target" ]] || fail "usage: $0 SNAPSHOT EMPTY_TARGET_DIRECTORY"

case "$target" in
  /|/Users|/home|/root|"$HOME"|.) fail "refusing broad or unsafe restore target: $target" ;;
esac
[[ ! -e "$target" ]] || fail "target already exists: $target"
mkdir -p "$target"
chmod 700 "$target"

echo "Restoring snapshot $snapshot into new directory $target"
restic restore "$snapshot" --tag freedocs --target "$target"

manifest=$(find "$target" -type f -name manifest.sha256 -print -quit)
[[ -n "$manifest" ]] || fail "manifest.sha256 not found in restored snapshot"
backup_root=$(dirname "$manifest")
(
  cd "$backup_root"
  sha256sum -c manifest.sha256
)

[[ -s "$backup_root/postgres.dump" ]] || fail "PostgreSQL dump is missing or empty"
[[ -f "$backup_root/config/.env" ]] || fail "generated .env is missing"
[[ -d "$backup_root/objects" ]] || fail "object directory is missing"

echo "PASS restored files and SHA-256 manifest"
echo "Restored backup root: $backup_root"
echo "This is file-level recovery only. Restore into an isolated stack and pass browser acceptance before declaring RECOVERY_READY."
