# PostgreSQL replication and high availability

Read-only diagnostics with green/red criteria. Resolve which host holds which role from the site
inventory -- the `## Hosts` table's Role column. Do not assume.

---

## 1. Replication status (run on the primary)

```bash
psql -U postgres -c "
SELECT
  client_addr,
  usename,
  application_name,
  state,
  sync_state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS replay_lag_bytes,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication
ORDER BY client_addr;
"
```

**Green:** Every expected replica present with `state = streaming`, `replay_lag` under a second, and
a small `replay_lag_bytes`.

**Red:** A replica missing from the output entirely, `state` other than `streaming`, large
`replay_lag`, or a replica stuck at a fixed LSN across repeated runs.

Compare the row count against the inventory's replica count. A replica that has silently stopped
connecting does not appear here at all, which is easy to miss when reading the output alone.

## 2. Replica status (run on each replica)

```bash
psql -U postgres -c "
SELECT
  status,
  received_lsn,
  latest_end_lsn,
  latest_end_time,
  conninfo,
  now() - latest_end_time AS time_since_last_wal
FROM pg_stat_wal_receiver;
"
```

**Green:** `status = streaming`, `time_since_last_wal` a few seconds at most.

**Red:** Status not streaming, or a large gap since the last WAL was received.

An empty result set on a host you believe is a replica means the WAL receiver is not running -- the
host may have been promoted, or recovery may have failed.

## 3. Recovery configuration (on replicas)

```bash
# PostgreSQL 12+ signals standby mode with a file, not recovery.conf
ls -la "$PGDATA/standby.signal" 2>/dev/null

psql -U postgres -c "
SELECT name, setting
FROM pg_settings
WHERE name IN ('primary_conninfo', 'primary_slot_name', 'hot_standby', 'restore_command')
ORDER BY name;
"

# Definitive check
psql -U postgres -c "SELECT pg_is_in_recovery();"
```

`pg_is_in_recovery()` returning `false` on a host the inventory calls a replica is a serious
finding: either it was promoted without the inventory being updated, or there are now two writable
primaries and writes are diverging.

## 4. Failover readiness

```bash
which patronictl 2>/dev/null && patronictl list
which repmgr 2>/dev/null && repmgr cluster show
dpkg -l 2>/dev/null | grep -i 'patroni\|repmgr'
```

**Green:** Patroni, repmgr, or an equivalent, with failover that has been tested.

**Red:** No failover automation. Failover then requires manual intervention during an outage, at the
worst possible time, by whoever is awake.

If no tool is found, the manual path is:

```bash
# On the chosen replica
psql -U postgres -c "SELECT pg_promote();"
```

Then update DNS, connection strings, and application configuration to point at the promoted host.
That last step is the one that gets forgotten and is usually the longer half of the outage.

> [!CAUTION]
> Promotion is not reversible. The old primary cannot rejoin as a replica without `pg_rewind` or a
> fresh base backup. Confirm the old primary is genuinely gone -- and stays gone -- before promoting,
> or you get split-brain with writes landing on both.

Where automation is absent, the highest-value output of an assessment is a written runbook with the
exact promotion steps for this estate. See the `incident-response` skill's runbook template.
