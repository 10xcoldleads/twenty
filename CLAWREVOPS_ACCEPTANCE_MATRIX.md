# ClawRevOps Twenty acceptance matrix

This matrix separates verified CRM behavior from features that require an
external provider, an enterprise license, or owner-held credentials. A feature
is not considered verified merely because its page renders.

## Automated production gate

Run:

```sh
cd /opt/twenty-crm/packages/twenty-docker
./clawrevops-acceptance.sh
```

The gate must pass before and after every deployment or upgrade.

## Verified behavior

| Area | Evidence |
| --- | --- |
| Public deployment | Local and public `/healthz` return success through the named Cloudflare Tunnel. |
| Authentication boundary | Unauthenticated `/rest/people` returns HTTP 403. Public invite links are disabled and workspace discovery is hidden. |
| Container isolation | PostgreSQL and Redis have no published host ports. |
| Workspace roles | Admin retains full access. Member cannot update all settings, globally soft-delete records, or permanently destroy records. |
| Companies and people | Create, update, search, filter, sort, persist, and relate records. |
| Opportunities | Kanban view creation and drag/move from Screening to Proposal persisted. |
| Tasks and notes | Related task and note creation persisted and appeared in global search. |
| Dashboards | CRM charts, totals, counts, rich text, and iframe widget rendered. |
| Custom data model | Created `Acceptance Asset`, added a select field, created/updated a record, and removed the temporary object after testing. |
| Export | A custom record exported to a valid CSV file. |
| Soft delete and restore | The custom record received a non-null `deletedAt`, then `PATCH /rest/restore/acceptanceAssets/{id}` returned HTTP 200 and PostgreSQL confirmed it active. |
| Workflows | Person-created automation completed, derived a domain, created/found a company, and linked the person. |
| REST API | Temporary keys passed create/read/update/delete and single-record restore. Keys were revoked or deleted after testing, and rejected keys returned HTTP 403. |
| Webhooks | Person event reached a temporary receiver; the webhook was then removed. |
| Transactional email | Resend SMTP is configured with a sending-only key scoped to `clawrevops.ai`; Twenty accepted a password-reset request and Resend recorded delivery to the owner address. |
| Backup and restore | Custom-format PostgreSQL backup restored into a disposable database with all 97 current source tables; disposable database was removed. |
| Resilience | Application-tier and Cloudflare Tunnel restarts recovered with persisted records and sessions. |
| Controlled load | 40 public health requests at ten-way concurrency all returned HTTP 200 with zero container restarts. |
| Responsive baseline | Desktop and 390×844 viewport checks found no horizontal page overflow on the primary CRM screens. |

## Enabled but requiring further production inputs

| Feature | Current state | Required input |
| --- | --- | --- |
| Two-factor authentication | Available, not enforced | Owner must enroll an authenticator before workspace-wide enforcement. |
| Gmail and Google Calendar | Disabled | Google OAuth client ID and secret, plus an owner connection. |
| Microsoft email/calendar | Disabled | Microsoft OAuth credentials, plus an owner connection. |
| IMAP/SMTP | Form and blank-state validation verified | A real mailbox and app password for live send/receive validation. |
| AI agents/chat | UI is present; no provider is configured | Model provider credentials, model selection, budget, and agent permission policy. |
| Durable attachments | Local volume only | S3- or R2-compatible bucket and credentials. |
| VPS hosting | Current host is Windows/WSL | Restore SSH access to the configured VPS, then migrate Compose, data, and the tunnel token. |

## Intentionally unavailable

| Feature | Reason |
| --- | --- |
| Enterprise audit logs | Requires a Twenty Enterprise license. |
| Enterprise SSO and organization controls | Requires a Twenty Enterprise license and identity-provider configuration. |
| Billing/seat-management flows | Not applicable to this self-hosted community deployment without an enterprise subscription. |

## Open observations

- A Windows/WSL sleep-resume produced one BullMQ stalled email-import cron job
  and two associated “missing lock” log lines. BullMQ retried the job
  successfully one minute later, Redis reported zero evictions, and the event
  did not recur while the host remained awake. This is another reason to move
  the stack to an always-on Linux VPS.
- The deleted-record command was discovered through command search rather than
  the view options menu. This is functional but less discoverable than it should
  be for non-technical users. The REST restore-path bug encountered during this
  test is corrected in the pinned ClawRevOps image and protected by regression
  tests.
- Data-model record counts use PostgreSQL planner estimates. New or restored
  tables can display zero until PostgreSQL runs `ANALYZE`.
