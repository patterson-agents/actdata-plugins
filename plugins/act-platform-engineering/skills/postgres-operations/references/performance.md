# PostgreSQL performance

Read-only diagnostics with green/red criteria. Set `DB` from the site inventory before running
anything here:

```bash
DB="<database from inventory>"
```

---

## 1. Version and database size

```bash
psql -U postgres -c "SELECT version();"

psql -U postgres -d "$DB" -c "
SELECT current_database(),
       pg_size_pretty(pg_database_size(current_database())) AS db_size;
"
```

Establishes what you are actually looking at. A surprising database size is itself a finding.

## 2. Active connections and state

```bash
psql -U postgres -d "$DB" -c "
SELECT
  state,
  count(*) AS count,
  max(now() - state_change) AS longest
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
GROUP BY state
ORDER BY count DESC;
"
```

**Green:** Mostly `idle`, a few `active`. No `idle in transaction` older than a few seconds.

**Red:** Many `idle in transaction`, or `active` queries running for minutes or hours. Indicates
connection leaks or long-running queries blocking vacuum and causing bloat.

## 3. Connection utilization

```bash
psql -U postgres -c "
SELECT setting AS max_connections FROM pg_settings WHERE name = 'max_connections';
"

psql -U postgres -c "
SELECT count(*) AS current_connections FROM pg_stat_activity;
"
```

**Green:** Current connections below 70% of max.

**Red:** Near or at `max_connections`. Consider connection pooling (PgBouncer). Note that raising
`max_connections` without pooling trades one problem for a worse one, since each connection costs
memory.

## 4. pg_stat_statements: top queries

```bash
# Is the extension available?
psql -U postgres -d "$DB" -c "
SELECT * FROM pg_available_extensions WHERE name = 'pg_stat_statements';
"

# To install (requires shared_preload_libraries and a restart):
# psql -U postgres -d "$DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

# Top 20 by cumulative time -- what the database spends its life doing
psql -U postgres -d "$DB" -c "
SELECT
  queryid,
  calls,
  round(total_exec_time::numeric, 2) AS total_ms,
  round(mean_exec_time::numeric, 2)  AS mean_ms,
  round(max_exec_time::numeric, 2)   AS max_ms,
  rows,
  left(query, 80) AS query_preview
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
"

# Top 20 by mean time -- individually slow queries
psql -U postgres -d "$DB" -c "
SELECT
  queryid,
  calls,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  round(max_exec_time::numeric, 2)  AS max_ms,
  rows,
  left(query, 80) AS query_preview
FROM pg_stat_statements
WHERE calls > 10
ORDER BY mean_exec_time DESC
LIMIT 20;
"
```

**Action:** Any query with `mean_ms` above 1000, or whose `total_ms` dominates the list, is a
candidate for `EXPLAIN ANALYZE`.

The two orderings answer different questions. High `total_ms` with low `mean_ms` is a fast query
called constantly -- fix it by calling it less. High `mean_ms` with low `calls` is a slow query --
fix the query.

## 5. EXPLAIN ANALYZE a slow query

```bash
psql -U postgres -d "$DB" -c "
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
<query>;
"
```

> [!WARNING]
> `EXPLAIN ANALYZE` on an `UPDATE`, `DELETE` or `INSERT` **executes it**. Wrap those:
> `BEGIN; EXPLAIN ANALYZE ...; ROLLBACK;`

**What to look for:**

- `Seq Scan` on a large table -- missing index
- `Sort Method: external merge Disk` -- `work_mem` too low for this query
- `Nested Loop` with estimated rows far from actual -- stale statistics, run `ANALYZE`
- `Buffers: shared read` much higher than `shared hit` -- working set is not in cache

## 6. Sequential scans versus index scans

```bash
psql -U postgres -d "$DB" -c "
SELECT
  schemaname,
  relname AS table_name,
  seq_scan,
  seq_tup_read,
  idx_scan,
  idx_tup_fetch,
  n_live_tup AS row_estimate,
  CASE WHEN (seq_scan + idx_scan) > 0
    THEN round(100.0 * idx_scan / (seq_scan + idx_scan), 1)
    ELSE 0
  END AS idx_scan_pct
FROM pg_stat_user_tables
WHERE n_live_tup > 10000
ORDER BY seq_scan DESC
LIMIT 20;
"
```

**Green:** `idx_scan_pct` above 90% on large tables.

**Red:** Large tables with high `seq_scan` and low `idx_scan_pct`. Likely missing indexes. A
sequential scan on a small table is fine and often faster than an index scan, which is why the query
filters to tables above 10,000 rows.

## 7. Table bloat

```bash
psql -U postgres -d "$DB" -c "
SELECT
  schemaname,
  relname AS table_name,
  n_live_tup,
  n_dead_tup,
  CASE WHEN n_live_tup > 0
    THEN round(100.0 * n_dead_tup / n_live_tup, 1)
    ELSE 0
  END AS dead_pct,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 20;
"
```

**Green:** `dead_pct` below 10%, recent autovacuum timestamps.

**Red:** `dead_pct` above 20%, or `last_autovacuum` NULL or very old. Autovacuum is misconfigured or
overwhelmed. Check for `idle in transaction` sessions first -- they are the usual cause, because
autovacuum cannot reclaim tuples still visible to an open transaction.

## 8. Unused indexes

```bash
psql -U postgres -d "$DB" -c "
SELECT
  schemaname,
  relname AS table_name,
  indexrelname AS index_name,
  idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%pkey%'
  AND indexrelname NOT LIKE '%unique%'
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;
"
```

**Action:** Indexes with zero scans slow every write and waste space.

Two caveats before dropping any of them. Statistics reset on `pg_stat_reset()` and on some upgrade
paths, so a zero count may only mean "since the last reset". And an index unused on the primary may
be serving read queries on a replica -- check there too.

## 9. Key configuration parameters

```bash
psql -U postgres -c "
SELECT name, setting, unit, source, context
FROM pg_settings
WHERE name IN (
  'shared_buffers', 'effective_cache_size', 'work_mem', 'maintenance_work_mem',
  'max_connections', 'checkpoint_completion_target', 'wal_buffers',
  'max_wal_size', 'min_wal_size', 'random_page_cost', 'effective_io_concurrency',
  'huge_pages', 'max_worker_processes', 'max_parallel_workers_per_gather',
  'max_parallel_workers', 'max_parallel_maintenance_workers',
  'autovacuum_max_workers', 'autovacuum_naptime',
  'autovacuum_vacuum_cost_delay', 'autovacuum_vacuum_cost_limit',
  'log_min_duration_statement', 'log_checkpoints', 'log_lock_waits', 'track_io_timing'
)
ORDER BY name;
"
```

**Rules of thumb**, adjusted for actual RAM and workload:

| Parameter | Guidance |
|---|---|
| `shared_buffers` | ~25% of total RAM |
| `effective_cache_size` | ~75% of total RAM (an estimate for the planner, not an allocation) |
| `work_mem` | 32MB-256MB. Multiplied by concurrent sorts *and* connections, so a high value is how servers run out of memory. |
| `maintenance_work_mem` | 512MB-2GB |
| `checkpoint_completion_target` | 0.9 |
| `random_page_cost` | 1.1 for SSD/NVMe. The 4.0 default assumes spinning disks. |
| `effective_io_concurrency` | 200 for NVMe |
| `log_min_duration_statement` | 1000, or lower during an investigation |
| `track_io_timing` | `on` -- required for `EXPLAIN (BUFFERS)` to mean anything |

The `source` column matters: `default` means nobody has tuned this instance.

> [!NOTE]
> On a host where ZFS ARC also competes for RAM, `shared_buffers` cannot be sized from total RAM
> alone. See the `zfs-storage` skill's ARC sizing section.

## 10. Lock contention

```bash
psql -U postgres -d "$DB" -c "
SELECT
  blocked_locks.pid       AS blocked_pid,
  blocked_activity.usename  AS blocked_user,
  blocking_locks.pid      AS blocking_pid,
  blocking_activity.usename AS blocking_user,
  blocked_activity.query  AS blocked_query,
  blocking_activity.query AS blocking_query,
  now() - blocked_activity.query_start AS blocked_duration
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity
  ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
  ON blocking_locks.locktype = blocked_locks.locktype
  AND blocking_locks.database    IS NOT DISTINCT FROM blocked_locks.database
  AND blocking_locks.relation    IS NOT DISTINCT FROM blocked_locks.relation
  AND blocking_locks.page        IS NOT DISTINCT FROM blocked_locks.page
  AND blocking_locks.tuple       IS NOT DISTINCT FROM blocked_locks.tuple
  AND blocking_locks.virtualxid  IS NOT DISTINCT FROM blocked_locks.virtualxid
  AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
  AND blocking_locks.classid     IS NOT DISTINCT FROM blocked_locks.classid
  AND blocking_locks.objid       IS NOT DISTINCT FROM blocked_locks.objid
  AND blocking_locks.objsubid    IS NOT DISTINCT FROM blocked_locks.objsubid
  AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity
  ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
"
```

**Green:** Empty result set.

**Red:** Any row means active lock contention. A long `blocked_duration` is an outage in progress,
not a tuning observation.
