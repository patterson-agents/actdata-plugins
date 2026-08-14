---
name: zfs-storage
description: This skill should be used when the user asks to "check ZFS", "assess the pool", "is the pool healthy", "check zpool status", "why is ZFS slow", "tune ZFS for Postgres", "check recordsize", "are we taking snapshots", "check ARC hit ratio", "the pool is filling up", or mentions zpool, zfs get, scrub, vdev, raidz, ARC, L2ARC, sanoid, zfs-auto-snapshot, or write amplification on a database host. Covers pool health and capacity, dataset tuning for PostgreSQL, and snapshot policy.
version: 0.1.0
---

# ZFS Storage

Diagnostics and tuning guidance for ZFS on Linux, with emphasis on hosting a PostgreSQL data
directory. All commands here are read-only; tuning changes are called out explicitly.

## Before running anything

Resolve the target host from the site inventory. See the `infrastructure-inventory` skill.

## The three questions

1. **Is the pool healthy and is the data intact?** Pool state, device errors, scrub history.
2. **Is there enough free space?** ZFS is copy-on-write; a full pool is a slow pool.
3. **Is it tuned for the workload on it?** Recordsize, compression, ARC sizing.

## The single highest-impact finding

On a pool hosting PostgreSQL, check `recordsize` first.

The ZFS default is 128K. PostgreSQL writes in 8K pages. Every 8K page write becomes a 128K
read-modify-write, a 16x write amplification that shows up as inexplicable I/O load and premature
SSD wear. Setting `recordsize=8K` or `16K` on the Postgres dataset is usually the largest single
improvement available on such a host.

> [!IMPORTANT]
> Changing `recordsize` affects **new writes only**. Existing data keeps its original record size.
> Realising the full benefit requires recreating the dataset and reloading the data, which is a
> maintenance-window operation, not a live tweak.

## Settings that are never correct on a database host

| Setting | Why it is wrong |
|---|---|
| `sync=disabled` | Acknowledges writes that are not on stable storage. A power loss silently loses committed transactions. Postgres believes its `fsync` succeeded. Never do this on a database. |
| `checksum=off` | Discards the main reason to run ZFS at all. |
| `atime=on` | Turns every read into a metadata write. Costs performance for information nothing uses. |

## Reference material

| File | Covers |
|---|---|
| `references/pool-health.md` | `zpool status`, capacity and fragmentation, dataset space, vdev topology, scrub schedule |
| `references/tuning-for-postgres.md` | Dataset property table, ARC statistics and hit ratio, ARC versus `shared_buffers` sizing |
| `references/snapshots.md` | Current snapshot state, snapshot tooling, space consumption and retention |

## When to hand off

| Symptom | Skill or agent |
|---|---|
| Slow queries that survive correct recordsize | `postgres-operations` skill |
| Drive wear, SMART attributes, PLP | `linux-host-tuning` skill, disk health section |
| Kernel memory parameters interacting with ARC | `linux-host-tuning` skill |
| A degraded pool during a live outage | `incident-response` skill |
