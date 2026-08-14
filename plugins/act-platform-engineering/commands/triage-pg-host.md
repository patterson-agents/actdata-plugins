---
description: Run a ten-section read-only triage on a PostgreSQL host covering system, storage, drives, database, replication and kernel
argument-hint: "[host] [database]"
allowed-tools: Read, Bash, Grep, Glob
---

# Triage a PostgreSQL host

One fast pass across every layer of a database host. Use it as the opening move on any
investigation, or as a routine check.

This is deliberately broad rather than deep. It exists to tell you *which* of the focused assessments
to run next.

## Resolve the target

Host and database from `$ARGUMENTS`, else from `.claude/act-platform-engineering.local.md` (the
`## Hosts` and `## Databases` tables), else ask. Never assume either.

## Run it

The script is bundled with the plugin:

```bash
# Remotely, which is the usual case
ssh <host> "bash -s" -- <database> < "${CLAUDE_PLUGIN_ROOT}/scripts/triage-pg-host.sh"

# Locally on the host
"${CLAUDE_PLUGIN_ROOT}/scripts/triage-pg-host.sh" <database>

# Captured for review
ssh <host> "bash -s" -- <database> < "${CLAUDE_PLUGIN_ROOT}/scripts/triage-pg-host.sh" \
  > "triage-$(date +%Y%m%d-%H%M).log"
```

The database argument is optional. Without it the host-level sections still run and the
database-specific ones are skipped, which is useful when triaging a host whose database is not
reachable.

The script is read-only throughout: no DDL, no setting changes, no writes outside stdout.

## What it covers

| Section | Reads |
|---|---|
| 1-2 | Hostname, OS, kernel, uptime, memory, CPU topology |
| 3 | Pool status and capacity |
| 4 | NVMe SMART: wear, spare, temperature, media errors |
| 5-6 | PostgreSQL version, database size, connection states |
| 7 | Replication status, and whether this host is in recovery |
| 8 | WAL archive status and replication slots |
| 9 | Dataset properties for PostgreSQL data |
| 10 | Key sysctls and transparent huge pages |

## Interpreting the output

The script prints an anomaly checklist at the end. Work through it, then decide which focused
assessment to run.

| What you see | Go to |
|---|---|
| Pool errors, capacity, `recordsize=128K` | `/act-platform-engineering:assess-zfs` |
| Drive wear or SMART warnings | `/act-platform-engineering:assess-disks` |
| Connection or query problems | `/act-platform-engineering:assess-postgres` |
| Replication state or lag | `/act-platform-engineering:assess-replication` |
| `last_failed_wal`, slot retention | `/act-platform-engineering:assess-backups` |
| Sysctl or THP values | `/act-platform-engineering:assess-kernel` |

## Two results that end the triage early

**An inactive replication slot retaining WAL** will fill the disk and stop the database. Handle it
before anything else on the list.

**`pg_is_in_recovery()` returning false on a host the inventory calls a replica** means either an
unrecorded promotion or two writable primaries. Stop and establish which, before any further
diagnosis.

## Note on interpretation

A section that prints nothing is ambiguous: the tool may be absent, the permission may be missing, or
the result may genuinely be empty. Say which, rather than reporting an empty section as healthy. If
`zpool status` printed "ZFS not available", that is a fact about the host, not a gap in the check.
