---
name: postgres-operations
description: This skill should be used when the user asks to "assess Postgres", "check the database", "why is the database slow", "check replication", "is replication lagging", "are backups working", "check WAL archiving", "find slow queries", "is autovacuum keeping up", "check for bloat", "review Postgres configuration", or mentions pg_stat_statements, replication slots, WAL shipping, failover readiness, table bloat, or connection exhaustion. Provides diagnostic commands with green/red criteria for PostgreSQL performance, backup and recovery, and replication and high availability.
version: 0.1.0
---

# PostgreSQL Operations

Diagnostic commands with pass/fail criteria for assessing a PostgreSQL instance. Every command is
read-only unless explicitly marked otherwise.

## Before running anything

Resolve the target host and database from the site inventory. See the `infrastructure-inventory`
skill: arguments first, then `.claude/act-platform-engineering.local.md`, then ask. **Never assume a
hostname or database name.**

Commands below use `$DB` for the database. Set it once from the resolved inventory value:

```bash
DB="<database from inventory>"
```

## Orientation: what is at stake

Work these three questions in order. They are ordered by blast radius, not by how interesting the
answer is.

1. **Is the database serving traffic, and is the data safe?** Connections, locks, replication lag,
   WAL archive status. Nothing else matters until these are answered.
2. **Is performance acceptable?** Slow queries, missing indexes, bloat, cache hit ratios,
   autovacuum health.
3. **Is the configuration sound?** Tuning parameters, version, extensions, monitoring coverage.

Identify which of the three the user is actually asking about before suggesting anything.

## Reads before writes

Never propose a change without seeing current state. The `pg_stat_*` views are the source of truth;
recollection is not. Run the relevant query, read the actual output, then reason.

## Production safety

> [!CAUTION]
> `EXPLAIN ANALYZE` on an `UPDATE` or `DELETE` **executes the statement**. Wrap it:
> `BEGIN; EXPLAIN ANALYZE ...; ROLLBACK;`

| Rule | Why |
|---|---|
| `VACUUM FULL` never during business hours | Takes an ACCESS EXCLUSIVE lock for the duration. Use `REINDEX CONCURRENTLY` or `pg_repack`. |
| `EXPLAIN ANALYZE` on `UPDATE`/`DELETE` **executes the statement** | Wrap it: `BEGIN; EXPLAIN ANALYZE ...; ROLLBACK;` |
| Anything on a primary affects replicas | Consider replication lag and lock propagation before acting. |
| Dropping an index is not free to reverse | Rebuilding a large index can take hours. Verify it is unused on replicas too. |

## Diagnostic flow

Follow this order when the symptom is vague ("the database is slow"):

1. `pg_stat_activity` -- what is running right now
2. `pg_stat_statements` -- what is expensive over time
3. `pg_stat_user_tables` / `pg_stat_user_indexes` -- usage patterns and bloat
4. `pg_stat_replication` (primary) / `pg_stat_wal_receiver` (replica) -- HA state
5. `pg_stat_archiver` -- WAL shipping health

## Signals that are almost always real problems

- **`idle in transaction` sessions.** They block autovacuum and cause table bloat. A session idle in
  transaction for hours is a connection-handling bug in the application.
- **Inactive replication slots.** They retain WAL indefinitely and will fill the disk. This is one
  of the few Postgres failure modes that takes the primary down.
- **Stale statistics.** Large gaps between estimated and actual row counts in `EXPLAIN` mean the
  planner is choosing blind. Run `ANALYZE`.
- **`Sort Method: external merge Disk` in `EXPLAIN`.** `work_mem` is too low for the query.
- **`n_dead_tup` above 20% of `n_live_tup`.** Autovacuum is not keeping up.

## Reference material

| File | Covers |
|---|---|
| `references/performance.md` | Version, connections, `pg_stat_statements`, `EXPLAIN`, scans, bloat, unused indexes, configuration parameters, lock contention |
| `references/backups-and-recovery.md` | WAL archiving status and lag, base backup schedule, replication slots |
| `references/replication-and-ha.md` | Primary and replica status, recovery configuration, failover readiness |

## When to hand off

| Symptom | Skill or agent |
|---|---|
| Filesystem write amplification, recordsize | `zfs-storage` skill |
| Memory pressure between ARC and `shared_buffers` | `zfs-storage` skill, ARC sizing section |
| Kernel parameters, transparent huge pages, ulimits | `linux-host-tuning` skill |
| Backup destination storage capacity | `linux-host-tuning` skill |
| An active outage rather than an assessment | `incident-response` skill |
