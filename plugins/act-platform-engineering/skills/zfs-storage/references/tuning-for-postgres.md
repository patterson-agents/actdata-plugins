# ZFS tuning for PostgreSQL

---

## 1. Dataset properties

```bash
# Locate the PostgreSQL data dataset
zfs list -o name,mountpoint | grep -i 'postgres\|pgdata\|pgsql'

# Then inspect it
DATASET="<pool/dataset from the previous command>"
zfs get recordsize,compression,atime,logbias,primarycache,secondarycache,sync,checksum,xattr,acltype "$DATASET"
```

**Target values for a PostgreSQL data directory:**

| Property | Recommended | Why |
|---|---|---|
| `recordsize` | `8K` or `16K` | Matches PostgreSQL's 8KB page. The 128K default causes ~16x write amplification. |
| `compression` | `lz4` or `zstd` | Net performance gain -- less I/O outweighs the CPU. `lz4` for lowest CPU, `zstd` for ratio. |
| `atime` | `off` | Removes a metadata write on every read. |
| `logbias` | `latency` | Optimises for low-latency writes. This is the default. |
| `primarycache` | `all` | Default. Fine. |
| `secondarycache` | `all` | Default. Fine unless there is no L2ARC. |
| `sync` | `standard` | **Never** `disabled` on a database. See below. |
| `checksum` | `on` | Data integrity verification. Never disable. |

> [!CAUTION]
> `sync=disabled` makes ZFS acknowledge writes before they reach stable storage. PostgreSQL's
> `fsync` returns success for data that is still only in RAM. A power loss then produces a database
> that believes committed transactions are durable when they are gone. This corrupts the write-ahead
> log's guarantees, which is the one thing crash recovery depends on.

### On changing recordsize

`recordsize` applies to **new writes only**. An existing dataset keeps its 128K records for existing
data. Options, in increasing order of benefit and disruption:

1. Set it and let natural churn migrate the hot data over time. No downtime, partial benefit.
2. Create a new dataset with the correct recordsize, stop Postgres, copy the data directory across,
   restart. Full benefit, requires a maintenance window.
3. Dump and reload into a correctly configured dataset. Full benefit, longest outage.

Measure before choosing. If the working set is small and churns constantly, option 1 may converge
within days.

## 2. ARC statistics

```bash
# Full summary if available
arc_summary 2>/dev/null || cat /proc/spl/kstat/zfs/arcstats

# Hit ratio
awk '/^hits/ {hits=$3} /^misses/ {misses=$3} END {printf "ARC Hit Ratio: %.1f%%\n", 100*hits/(hits+misses)}' /proc/spl/kstat/zfs/arcstats

# Current size
awk '/^size/ {printf "ARC Size: %.1f GB\n", $3/1073741824; exit}' /proc/spl/kstat/zfs/arcstats
```

**Green:** Hit ratio above 90%, ARC using the RAM available to it.

**Red:** Hit ratio below 80% (the working set does not fit), or an ARC artificially capped well
below available RAM.

Note that the hit ratio is cumulative since boot. On a long-uptime host it is dominated by history
and can hide a recent regression. For a current read, sample it twice a few minutes apart and
compare the deltas.

## 3. ARC size limits

```bash
cat /sys/module/zfs/parameters/zfs_arc_max
cat /sys/module/zfs/parameters/zfs_arc_min

free -h | head -2
```

`0` means auto, which lets ZFS take up to half of RAM by default on Linux.

## 4. ARC and shared_buffers must be sized together

```bash
TOTAL_RAM_GB=$(awk '/MemTotal/ {printf "%.1f", $2/1048576}' /proc/meminfo)
ARC_MAX_GB=$(awk '{printf "%.1f", $1/1073741824}' /sys/module/zfs/parameters/zfs_arc_max)
SHARED_BUFFERS=$(psql -U postgres -t -c "SHOW shared_buffers;" 2>/dev/null | xargs)

echo "Total RAM:         ${TOTAL_RAM_GB} GB"
echo "ZFS ARC max:       ${ARC_MAX_GB} GB (0 = auto)"
echo "PG shared_buffers: ${SHARED_BUFFERS}"
```

This is the check most often skipped, and it is where database hosts on ZFS get into trouble.

ARC and `shared_buffers` are two independent caches competing for the same RAM, and neither knows
about the other. The standard "`shared_buffers` = 25% of RAM" guidance assumes the other 75% is
available to the OS page cache. On ZFS, ARC is trying to take half of it.

A workable split:

| Consumer | Share |
|---|---|
| `shared_buffers` | 25% of RAM |
| ZFS ARC (`zfs_arc_max`) | up to 50% of RAM |
| OS, connections, work_mem, maintenance | remaining 25% |

Leaving `zfs_arc_max` at auto on a database host means ZFS and Postgres both size themselves as
though they had the machine to themselves. Under memory pressure, ARC does release memory, but not
always fast enough to prevent the OOM killer choosing a Postgres backend.

Also note that data cached in both ARC and `shared_buffers` is stored twice, so the effective cache
is smaller than the sum. Some operators deliberately shrink `shared_buffers` on ZFS and let ARC do
more of the work, since ARC handles compression transparently.
