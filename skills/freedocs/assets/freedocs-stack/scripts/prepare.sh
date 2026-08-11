#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$root_dir/.env"
nginx_file="$root_dir/nginx/freedocs.conf"

if [[ -e "$env_file" || -e "$nginx_file" ]]; then
  echo "Refusing to overwrite generated configuration." >&2
  echo "Back up and remove .env and nginx/freedocs.conf only if a fresh configuration is intended." >&2
  exit 1
fi

for command_name in openssl sed; do
  command -v "$command_name" >/dev/null || {
    echo "Missing required command: $command_name" >&2
    exit 1
  }
done

read -r -p "Knowledge-base domain (for example kb.example.com): " domain
if [[ ! "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ ]] || [[ "$domain" != *.* ]]; then
  echo "Invalid domain" >&2
  exit 1
fi

read -r -p "Owner email: " owner_email
if [[ ! "$owner_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
  echo "Invalid email" >&2
  exit 1
fi

read -r -s -p "Owner login password (stored only as bcrypt): " owner_password
printf '\n'
read -r -s -p "Repeat password: " owner_password_confirm
printf '\n'
if [[ -z "$owner_password" || "$owner_password" != "$owner_password_confirm" ]]; then
  echo "Passwords are empty or do not match" >&2
  exit 1
fi

if command -v htpasswd >/dev/null; then
  password_hash=$(printf '%s\n' "$owner_password" | htpasswd -niBC 12 "" | tr -d '\n' | sed 's/^://')
elif command -v docker >/dev/null; then
  password_hash=$(printf '%s\n' "$owner_password" | docker run --rm -i httpd:2.4-alpine htpasswd -niBC 12 "" | tr -d '\n' | sed 's/^://')
else
  echo "htpasswd or Docker is required to generate the bcrypt hash" >&2
  exit 1
fi
unset owner_password owner_password_confirm

cp "$root_dir/.env.example" "$env_file"

replace_value() {
  local key=$1
  local value=$2
  sed -i.bak "s|^${key}=.*$|${key}=${value}|" "$env_file"
}

secret_key=$(openssl rand -hex 32)
utils_secret=$(openssl rand -hex 32)
postgres_password=$(openssl rand -hex 24)
minio_root_user=$(openssl rand -hex 12)
minio_root_password=$(openssl rand -hex 32)
object_access_key=$(openssl rand -hex 12)
object_secret_key=$(openssl rand -hex 32)
oidc_secret=$(openssl rand -hex 32)
user_id=$(openssl rand -hex 16)
owner_username=${owner_email%@*}

replace_value FREEDOCS_DOMAIN "$domain"
replace_value URL "https://$domain"
replace_value SECRET_KEY "$secret_key"
replace_value UTILS_SECRET "$utils_secret"
replace_value POSTGRES_PASSWORD "$postgres_password"
replace_value DATABASE_URL "postgres://outline:${postgres_password}@postgres:5432/outline"
replace_value MINIO_ROOT_USER "$minio_root_user"
replace_value MINIO_ROOT_PASSWORD "$minio_root_password"
replace_value AWS_ACCESS_KEY_ID "$object_access_key"
replace_value AWS_SECRET_ACCESS_KEY "$object_secret_key"
replace_value AWS_S3_UPLOAD_BUCKET_URL "https://$domain"
replace_value OIDC_CLIENT_SECRET "$oidc_secret"
replace_value OIDC_AUTH_URI "https://$domain/dex/auth"
replace_value OIDC_LOGOUT_URI "https://$domain"
replace_value DEX_ISSUER_URL "https://$domain/dex"
replace_value OUTLINE_OIDC_CALLBACK_URL "https://$domain/auth/oidc.callback"
replace_value DEX_STATIC_EMAIL "$owner_email"
replace_value DEX_STATIC_USERNAME "$owner_username"
replace_value DEX_STATIC_USER_ID "$user_id"
password_hash_for_compose=$(printf '%s' "$password_hash" | sed 's/\$/$$/g')
replace_value DEX_STATIC_PASSWORD_HASH "$password_hash_for_compose"

rm -f "$env_file.bak"
chmod 600 "$env_file"
sed "s/__DOMAIN__/$domain/g" "$root_dir/nginx/freedocs.conf.template" > "$nginx_file"

echo "Created $env_file with mode 600"
echo "Created $nginx_file"
echo "No plaintext login password was stored."
