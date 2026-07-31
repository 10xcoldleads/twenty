# ClawRevOps Twenty deployment

This fork is kept source-compatible with upstream Twenty. The running CRM uses
Twenty's official application image. The Compose file has one deployment fix:
it forwards the documented logic-function and code-interpreter settings to both
the server and worker containers.

## Production URL

- App: https://twenty.clawrevops.ai
- Health: https://twenty.clawrevops.ai/healthz
- Cloudflare Tunnel: `clawrevops-twenty-crm`
- Tunnel ID: `ccc2beef-593a-41ab-bbec-d32e6f428308`
- Workspace: `ClawRevOps Twenty CRM`
- Owner email: `ty@omnimetamarketing.com`

Cloudflare terminates HTTPS and forwards requests through an outbound-only
tunnel. PostgreSQL and Redis are not exposed publicly.

## Runtime

- WSL distribution: `OpenClawGateway`
- Repository: `/opt/twenty-crm`
- Compose directory: `/opt/twenty-crm/packages/twenty-docker`
- Image: `twentycrm/twenty:v2.25.1`
- Services: `server`, `worker`, `db`, and `redis`
- Canonical `SERVER_URL`: `https://twenty.clawrevops.ai`

Secrets live only in the ignored Compose `.env` file. Do not commit that file.

## Security posture

- Password authentication is enabled.
- Public invite links are disabled.
- Workspace discovery is hidden.
- Multi-workspace mode is disabled.
- Google and Microsoft sign-in are disabled until their OAuth credentials are
  configured; password authentication remains enabled.
- The default `Member` role cannot soft-delete or permanently destroy all
  workspace records. The `Admin` role retains full control.
- PostgreSQL and Redis are private Docker services.
- Cloudflare Tunnel is the only public application path.
- Two-factor authentication is available but not yet enforced. The owner must
  enroll an authenticator before workspace-wide enforcement can be enabled.
- The current file store is local. Configure S3-compatible durable storage
  before relying on the CRM for production attachments.
- Logic functions run with `LOGIC_FUNCTION_TYPE=LOCAL` so trusted workflow code
  can execute. LOCAL is not sandboxed; only workspace owners should be able to
  install or edit code steps. `CODE_INTERPRETER_TYPE` remains `DISABLED`.

## Routine checks

```sh
cd /opt/twenty-crm/packages/twenty-docker
docker compose ps
curl -fsS http://localhost:3000/healthz
systemctl is-active cloudflared
```

The external check is:

```sh
curl -fsS https://twenty.clawrevops.ai/healthz
```

## Start, stop, and logs

```sh
cd /opt/twenty-crm/packages/twenty-docker
docker compose up -d
docker compose logs --tail=200 server worker
docker compose stop
```

Docker and `cloudflared` are enabled as systemd services. The Windows host must
be running for this deployment to be reachable. Move the same Compose stack and
tunnel token to the configured VPS when its SSH service is restored.

## Backup and restore

Create a custom-format database backup and copy it outside the container:

```sh
mkdir -p /opt/twenty-backups
docker exec twenty-db-1 pg_dump -U postgres -Fc -f /tmp/twenty.dump default
docker cp twenty-db-1:/tmp/twenty.dump /opt/twenty-backups/twenty.dump
```

Validate a backup with a disposable database:

```sh
docker cp /opt/twenty-backups/twenty.dump twenty-db-1:/tmp/twenty.dump
docker exec twenty-db-1 createdb -U postgres twenty_restore_qa
docker exec twenty-db-1 pg_restore -U postgres -d twenty_restore_qa /tmp/twenty.dump
docker exec twenty-db-1 psql -U postgres -d twenty_restore_qa -Atc \
  "select count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema');"
docker exec twenty-db-1 dropdb -U postgres twenty_restore_qa
```

Verified backups:

- `/opt/twenty-backups/twenty-initial-verified.dump`
- `/opt/twenty-backups/twenty-post-acceptance.dump` (867,385 bytes, mode 600)

The post-acceptance backup restored into a disposable database containing 166
PostgreSQL tables and the disposable database was then removed.

## Automated acceptance gate

Run the repository-owned production gate after deployment, configuration
changes, backups, or upgrades:

```sh
cd /opt/twenty-crm/packages/twenty-docker
./clawrevops-acceptance.sh
```

The gate checks container state, health endpoints, workflow runtime settings,
unauthenticated API denial, private PostgreSQL/Redis networking, workspace auth
and invite posture, least-privilege member permissions, completed workflow
evidence, workflow-created relations, and backup permissions.

## Acceptance evidence

Validated against the public HTTPS deployment on 2026-07-31:

- Owner login and authenticated workspace loading.
- Company and person creation with persistence.
- Opportunity Kanban view creation.
- Opportunity stage movement from Screening to Proposal.
- Related task creation on an opportunity.
- Note creation.
- Global search across people and tasks.
- Full application-tier restart with session and record persistence.
- Public and local health endpoints.
- PostgreSQL custom-format backup and scratch-database restore.
- Desktop and 390-pixel viewport rendering without horizontal overflow.
- Server and worker restart counts remained zero after recreation.
- REST API create, read, update, delete, and revoked-key rejection.
- Outbound webhook delivery for a person event, followed by webhook removal.
- Active person-created workflow completion, including domain extraction,
  company creation, and linking the person to the company.
- People filtering by email domain and ascending creation-date sorting.
- Dashboard charts, totals, CRM record counts, and iframe widget rendering.
- Forty public health requests at ten-way concurrency, all returning HTTP 200.
- Cloudflare Tunnel restart and automatic public endpoint recovery.
- Custom object and select-field creation, custom-record creation/update, CSV
  export, and soft deletion.
- PostgreSQL `ANALYZE` refreshed approximate data-model record counts and query
  planner statistics.

Records named `E2E Validation`, `Workflow Validation`, `Workflow Repaired`, and
`ClawRevOps Persistence QA`, plus the task/note prefixed with `E2E` and the
`Pipeline QA` view, are deliberate acceptance fixtures. Remove them only after
the remaining module tests finish.

## Upgrade

1. Read the Twenty release notes and backup PostgreSQL.
2. Update `TAG` in the ignored Compose `.env`.
3. Run `docker compose pull`.
4. Run `docker compose up -d`.
5. Verify local and public health, login, CRUD, and worker logs.
6. Keep the previous image tag until the post-upgrade checks pass.
