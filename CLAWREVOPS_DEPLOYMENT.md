# ClawRevOps Twenty deployment

This fork is kept source-compatible with upstream Twenty. The running CRM uses
Twenty's official Docker Compose stack without application-code modifications.

## Production URL

- App: https://twenty.clawrevops.ai
- Health: https://twenty.clawrevops.ai/healthz
- Cloudflare Tunnel: `clawrevops-twenty-crm`
- Tunnel ID: `ccc2beef-593a-41ab-bbec-d32e6f428308`

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

The initial verified backup is
`/opt/twenty-backups/twenty-initial-verified.dump`. It restored 97 application
tables successfully.

## Upgrade

1. Read the Twenty release notes and backup PostgreSQL.
2. Update `TAG` in the ignored Compose `.env`.
3. Run `docker compose pull`.
4. Run `docker compose up -d`.
5. Verify local and public health, login, CRUD, and worker logs.
6. Keep the previous image tag until the post-upgrade checks pass.

