#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/twenty-crm/packages/twenty-docker/.env}"

resend_api_key=''
IFS= read -r resend_api_key || [[ -n "$resend_api_key" ]]
[[ "$resend_api_key" =~ ^re_[A-Za-z0-9_-]{20,}$ ]] || {
  printf 'Invalid Resend key format\n' >&2
  exit 1
}

sed -i \
  -e '/^EMAIL_FROM_ADDRESS=/d' \
  -e '/^EMAIL_FROM_NAME=/d' \
  -e '/^EMAIL_DRIVER=/d' \
  -e '/^EMAIL_SMTP_HOST=/d' \
  -e '/^EMAIL_SMTP_PORT=/d' \
  -e '/^EMAIL_SMTP_USER=/d' \
  -e '/^EMAIL_SMTP_PASSWORD=/d' \
  -e '/^EMAIL_SMTP_NO_TLS=/d' \
  "$ENV_FILE"

{
  printf '%s\n' \
    'EMAIL_FROM_ADDRESS=notifications@clawrevops.ai' \
    'EMAIL_FROM_NAME=ClawRevOps CRM' \
    'EMAIL_DRIVER=smtp' \
    'EMAIL_SMTP_HOST=smtp.resend.com' \
    'EMAIL_SMTP_PORT=587' \
    'EMAIL_SMTP_USER=resend'
  printf 'EMAIL_SMTP_PASSWORD=%s\n' "$resend_api_key"
  printf '%s\n' 'EMAIL_SMTP_NO_TLS=false'
} >>"$ENV_FILE"

chmod 600 "$ENV_FILE"
[[ "$(grep -c '^EMAIL_SMTP_PASSWORD=re_' "$ENV_FILE")" == "1" ]]
printf 'Resend SMTP runtime configuration installed.\n'
