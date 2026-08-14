---
description: Check streaming replication health between a primary and its replicas, including failover readiness
argument-hint: "[primary-host]"
allowed-tools: Read, Bash, Grep, Glob
---

# Assess replication

Check that replication is streaming, that every expected replica is present, and that failover is
actually possible.

## Resolve the topology

Read `.claude/act-platform-engineering.local.md` and identify from the `## Hosts` table which host is
`primary` and which are `replica` or `standby`. Take an override from `$ARGUMENTS` if given.

**The expected replica list comes from the inventory.** This matters: a replica that has stopped
connecting does not appear in `pg_stat_replication` at all, so the check is a comparison against the
inventory, not a reading of the output alone. Without the inventory you cannot detect an absent
replica.

If the inventory does not record replicas, ask.

## Run the checks

Load the `postgres-operations` skill and work through `references/replication-and-ha.md`.

**On the primary:**

1. `pg_stat_replication` -- one row per connected replica
2. Confirm every replica from the inventory appears
3. `state = streaming` for each
4. `replay_lag` in both time and bytes
5. `sync_state`, so you know which replicas are synchronous

**On each replica:**

6. `pg_stat_wal_receiver` -- `status` and `latest_end_time`
7. `pg_is_in_recovery()` -- must return true
8. `standby.signal` present, `primary_conninfo` set

**Back on the primary:**

9. `pg_stat_archiver` -- `last_failed_wal` and archive lag
10. `pg_replication_slots` -- every slot active, retained WAL small

**Failover readiness:**

11. Is Patroni, repmgr, or an equivalent installed and tested?

## Findings that outrank the rest

| Finding | Why |
|---|---|
| An inactive replication slot retaining WAL | Fills the primary's disk and stops the database. Not a replication problem, a primary-outage problem. |
| A replica in the inventory but absent from `pg_stat_replication` | Silent replication failure. Recovery objective is already breached. |
| `pg_is_in_recovery()` false on a host recorded as a replica | Either an unrecorded promotion or two writable primaries diverging. |
| No failover automation | Recovery time is "however long it takes a human, at whatever hour" |

## Output

```markdown
## Replication assessment: [date]

### Topology
| Host | Role | State | Sync | Replay lag | Notes |
|---|---|---|---|---|---|

### Healthy
### Concerns
### Issues
```

Where failover automation is absent, the most useful deliverable is a written promotion runbook for
this specific estate. See the `incident-response` skill's runbook template.
