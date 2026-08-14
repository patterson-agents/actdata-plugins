---
description: Check WAL archiving, base backup schedule, backup destination health and restore capability
argument-hint: "[host]"
allowed-tools: Read, Bash, Grep, Glob
---

# Assess backups

Determine whether this database could actually be recovered, which is a different question from
whether backups are configured.

## Resolve the target

Host from `$ARGUMENTS`, else the `primary` role in
`.claude/act-platform-engineering.local.md`, else ask.

## Run the checks

Load the `postgres-operations` skill and work through `references/backups-and-recovery.md`.

1. **WAL archiving configuration.** `archive_mode`, `wal_level`, `archive_command`,
   `max_wal_senders` sized for current plus planned replicas.
2. **WAL archive lag.** `pg_stat_archiver` for `last_failed_wal` and time since last success.
3. **Base backup schedule.** Cron, systemd timers, `pgbackrest info` if present.
4. **Backup destination health.** Free space at the target, last successful backup timestamp,
   retention against capacity.
5. **Restore testing.** When was a restore last performed? Is the procedure documented? Is there
   somewhere to restore into?

## The three questions that actually matter

Configuration checks pass easily while recovery remains impossible. Answer these explicitly:

**Is there a base backup?** WAL shipping alone is not a backup strategy. WAL replays *forward from* a
base backup; with no base backup there is nothing to replay onto. A broken WAL chain and no base
backup means total loss.

**Is the destination independent of the source?** A backup written to the same pool, array or host as
the database protects against deletion and nothing else.

**Has a restore ever been performed?** A backup that has never been restored is a hypothesis. If no
restore test is on record, that is a finding in its own right, and it outranks a healthy-looking
schedule.

## Failure modes that look healthy

| Appearance | Reality |
|---|---|
| `archive_command` returns success every time | May be `true` or a script that swallows errors. WAL is being discarded while Postgres believes it is archived. |
| A backup job exists in cron | Says nothing about whether it has succeeded recently. Check the timestamps, not the schedule. |
| Backups present and recent | Untested. Restore time and restore viability are both unknown. |

## Output

```markdown
## Backup assessment: [host], [date]

### Recovery capability
- Point-in-time recovery possible: [yes / no / unknown]
- Recovery point objective actually achievable: [value or unknown]
- Last verified restore: [date or "never"]

### Healthy
### Concerns
### Issues
```

Lead with recovery capability, not with configuration. "Archiving is on" is not an answer to "could
we recover".
