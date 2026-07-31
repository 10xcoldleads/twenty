#!/usr/bin/env bash
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-twenty-db-1}"
BACKUP_DIR="${BACKUP_DIR:-/opt/twenty-backups}"
BACKUP_FILE="${BACKUP_FILE:-$BACKUP_DIR/twenty-final-2026-07-31.dump}"
RESTORE_DATABASE="${RESTORE_DATABASE:-twenty_restore_acceptance}"

install -d -m 700 "$BACKUP_DIR"
umask 077

docker exec "$DB_CONTAINER" pg_dump -U postgres -d default -Fc >"$BACKUP_FILE"
chmod 600 "$BACKUP_FILE"
[[ -s "$BACKUP_FILE" ]]

table_count_query="
  select count(*)
    from information_schema.tables
   where table_schema not in ('pg_catalog', 'information_schema')
"
source_table_count="$(
  docker exec "$DB_CONTAINER" \
    psql -U postgres -d default -Atc "$table_count_query"
)"

database_exists="$(
  docker exec "$DB_CONTAINER" \
    psql -U postgres -d postgres -Atc \
    "select count(*) from pg_database where datname = '$RESTORE_DATABASE'"
)"
[[ "$database_exists" == "0" ]] || {
  printf 'Refusing to overwrite existing restore database: %s\n' "$RESTORE_DATABASE" >&2
  exit 1
}

cleanup() {
  docker exec "$DB_CONTAINER" \
    dropdb -U postgres --if-exists "$RESTORE_DATABASE" >/dev/null
}
trap cleanup EXIT

docker exec "$DB_CONTAINER" createdb -U postgres "$RESTORE_DATABASE"
docker exec -i "$DB_CONTAINER" \
  pg_restore -U postgres -d "$RESTORE_DATABASE" --no-owner <"$BACKUP_FILE"

table_count="$(
  docker exec "$DB_CONTAINER" \
    psql -U postgres -d "$RESTORE_DATABASE" -Atc "$table_count_query"
)"
[[ "$table_count" == "$source_table_count" ]] || {
  printf \
    'Restore verification table mismatch: source=%s restored=%s\n' \
    "$source_table_count" \
    "$table_count" \
    >&2
  exit 1
}

printf 'PASS: backup restored all %s source tables\n' "$table_count"
stat -c 'PASS: backup=%n bytes=%s mode=%a' "$BACKUP_FILE"
