#!/usr/bin/env bash
set -euo pipefail

PUBLIC_URL="${PUBLIC_URL:-https://twenty.clawrevops.ai}"
WORKSPACE_NAME="${WORKSPACE_NAME:-ClawRevOps Twenty CRM}"
DB_CONTAINER="${DB_CONTAINER:-twenty-db-1}"
SERVER_CONTAINER="${SERVER_CONTAINER:-twenty-server-1}"
WORKER_CONTAINER="${WORKER_CONTAINER:-twenty-worker-1}"
REDIS_CONTAINER="${REDIS_CONTAINER:-twenty-redis-1}"
BACKUP_FILE="${BACKUP_FILE:-/opt/twenty-backups/twenty-final-2026-07-31.dump}"
EXPECTED_TWENTY_IMAGE="${EXPECTED_TWENTY_IMAGE:-clawrevops/twenty:v2.25.1-clawrevops.1}"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$1"
}

assert_equal() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  [[ "$actual" == "$expected" ]] ||
    fail "$label (expected '$expected', got '$actual')"
  pass "$label"
}

container_state() {
  docker inspect --format '{{.State.Status}}' "$1"
}

container_health() {
  docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1"
}

assert_equal "$(container_state "$SERVER_CONTAINER")" "running" "server container is running"
assert_equal "$(container_health "$SERVER_CONTAINER")" "healthy" "server container is healthy"
assert_equal "$(container_state "$WORKER_CONTAINER")" "running" "worker container is running"
assert_equal "$(container_state "$DB_CONTAINER")" "running" "database container is running"
assert_equal "$(container_health "$DB_CONTAINER")" "healthy" "database container is healthy"
assert_equal "$(container_state "$REDIS_CONTAINER")" "running" "Redis container is running"
assert_equal "$(container_health "$REDIS_CONTAINER")" "healthy" "Redis container is healthy"
assert_equal \
  "$(docker inspect --format '{{.Config.Image}}' "$SERVER_CONTAINER")" \
  "$EXPECTED_TWENTY_IMAGE" \
  "server runs the pinned ClawRevOps image"
assert_equal \
  "$(docker inspect --format '{{.Config.Image}}' "$WORKER_CONTAINER")" \
  "$EXPECTED_TWENTY_IMAGE" \
  "worker runs the pinned ClawRevOps image"
assert_equal \
  "$(docker inspect --format '{{.RestartCount}}' "$SERVER_CONTAINER")" \
  "0" \
  "server has not restarted unexpectedly"
assert_equal \
  "$(docker inspect --format '{{.RestartCount}}' "$WORKER_CONTAINER")" \
  "0" \
  "worker has not restarted unexpectedly"

assert_equal \
  "$(docker exec "$SERVER_CONTAINER" printenv LOGIC_FUNCTION_TYPE)" \
  "LOCAL" \
  "server logic functions are enabled"
assert_equal \
  "$(docker exec "$WORKER_CONTAINER" printenv LOGIC_FUNCTION_TYPE)" \
  "LOCAL" \
  "worker logic functions are enabled"
assert_equal \
  "$(docker exec "$WORKER_CONTAINER" printenv CODE_INTERPRETER_TYPE)" \
  "DISABLED" \
  "untrusted code interpreter is disabled"
assert_equal \
  "$(docker exec "$SERVER_CONTAINER" printenv EMAIL_DRIVER)" \
  "smtp" \
  "transactional email uses SMTP"
assert_equal \
  "$(docker exec "$SERVER_CONTAINER" printenv EMAIL_SMTP_HOST)" \
  "smtp.resend.com" \
  "transactional email uses Resend"
assert_equal \
  "$(docker exec "$SERVER_CONTAINER" printenv EMAIL_FROM_ADDRESS)" \
  "notifications@clawrevops.ai" \
  "transactional sender uses the verified domain"
[[ -n "$(docker exec "$SERVER_CONTAINER" printenv EMAIL_SMTP_PASSWORD)" ]] ||
  fail "transactional email credential is missing"
pass "transactional email credential is installed"

curl -fsS http://127.0.0.1:3000/healthz >/dev/null ||
  fail "local health endpoint failed"
pass "local health endpoint"

curl -fsS "$PUBLIC_URL/healthz" >/dev/null ||
  fail "public health endpoint failed"
pass "public health endpoint"

for container in "$SERVER_CONTAINER" "$WORKER_CONTAINER"; do
  recent_runtime_errors="$(
    docker logs --since 10m "$container" 2>&1 |
      grep -Eic 'Missing lock|stalled more than allowable limit|unhandled|fatal' ||
      true
  )"
  assert_equal \
    "$recent_runtime_errors" \
    "0" \
    "$container has no critical runtime errors in the last 10 minutes"
done

unauthenticated_status="$(
  curl -sS -o /dev/null -w '%{http_code}' "$PUBLIC_URL/rest/people"
)"
assert_equal "$unauthenticated_status" "403" "unauthenticated REST access is denied"

[[ -z "$(docker port "$DB_CONTAINER" 5432/tcp 2>/dev/null || true)" ]] ||
  fail "PostgreSQL is published outside the Docker network"
pass "PostgreSQL is not published"

[[ -z "$(docker port "$REDIS_CONTAINER" 6379/tcp 2>/dev/null || true)" ]] ||
  fail "Redis is published outside the Docker network"
pass "Redis is not published"

workspace_security="$(
  docker exec "$DB_CONTAINER" psql -U postgres -d default -At -F '|' -c "
    select
      \"isPublicInviteLinkEnabled\",
      \"workspaceDiscoverability\",
      \"isPasswordAuthEnabled\",
      \"isGoogleAuthEnabled\",
      \"isMicrosoftAuthEnabled\"
    from core.workspace
    where \"displayName\" = '$WORKSPACE_NAME';
  "
)"
assert_equal \
  "$workspace_security" \
  "f|HIDDEN|t|f|f" \
  "workspace invitation, discovery, and auth-provider posture"

member_permissions="$(
  docker exec "$DB_CONTAINER" psql -U postgres -d default -At -F '|' -c "
    select
      \"canUpdateAllSettings\",
      \"canSoftDeleteAllObjectRecords\",
      \"canDestroyAllObjectRecords\"
    from core.role
    where label = 'Member'
      and \"workspaceId\" = (
        select id from core.workspace where \"displayName\" = '$WORKSPACE_NAME'
      );
  "
)"
assert_equal "$member_permissions" "f|f|f" "default Member role uses least privilege"

workspace_schema="$(
  docker exec "$DB_CONTAINER" psql -U postgres -d default -At -c "
    select \"databaseSchema\"
    from core.workspace
    where \"displayName\" = '$WORKSPACE_NAME';
  "
)"
[[ "$workspace_schema" =~ ^workspace_[a-z0-9]+$ ]] ||
  fail "workspace schema could not be resolved safely"

completed_workflow_runs="$(
  docker exec "$DB_CONTAINER" psql -U postgres -d default -At -c "
    select count(*)
    from \"$workspace_schema\".\"workflowRun\"
    where status = 'COMPLETED';
  "
)"
(( completed_workflow_runs >= 2 )) ||
  fail "expected at least two completed workflow runs, got $completed_workflow_runs"
pass "completed workflow evidence exists"

linked_workflow_person="$(
  docker exec "$DB_CONTAINER" psql -U postgres -d default -At -c "
    select count(*)
    from \"$workspace_schema\".person
    where \"emailsPrimaryEmail\" = 'workflow-repaired@clawrevops-automation.test'
      and \"companyId\" is not null;
  "
)"
assert_equal "$linked_workflow_person" "1" "workflow-linked person and company persist"

[[ -s "$BACKUP_FILE" ]] || fail "verified backup is missing or empty: $BACKUP_FILE"
backup_mode="$(stat -c '%a' "$BACKUP_FILE")"
assert_equal "$backup_mode" "600" "verified backup permissions"

printf '\nTwenty production acceptance gate passed.\n'
