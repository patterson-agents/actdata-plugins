---
description: Assess ZFS pool health, capacity, dataset tuning and snapshot state on a host
argument-hint: "[host]"
allowed-tools: Read, Bash, Grep, Glob
---

# Assess ZFS

Pool health, capacity, tuning and snapshot policy for a ZFS host.

## Resolve the target

Host from `$ARGUMENTS`, else from `.claude/act-platform-engineering.local.md`, else ask. Note the
host's role -- the tuning expectations differ between a database host and a hypervisor.

## Run the checks

Load the `zfs-storage` skill.

**Pool health** (`references/pool-health.md`):

1. `zpool status -v` -- state, device errors, scrub history
2. `zpool list` -- capacity and fragmentation
3. `zfs list` -- dataset sizes and compression ratios
4. Pool topology -- mirror, raidz, or an unredundant stripe
5. Scrub schedule and last result

**Tuning** (`references/tuning-for-postgres.md`), where a database is present:

6. Dataset properties, `recordsize` first
7. ARC hit ratio
8. ARC size limits against total RAM
9. ARC and `shared_buffers` sized together

**Snapshots** (`references/snapshots.md`):

10. Current snapshot state and newest timestamp
11. Snapshot tooling and its schedule
12. Space consumed by snapshots

## Findings that outrank the rest

| Finding | Why |
|---|---|
| A pool with no redundancy under production data | One drive failure destroys everything. Outranks every tuning finding. |
| `sync=disabled` on a database dataset | Silently loses committed transactions on power loss. |
| Capacity above 80% | Copy-on-write performance degrades sharply, and it is non-linear. |
| Non-zero CKSUM on an ONLINE pool | Earliest warning of a failing drive; easy to miss because the pool looks healthy. |
| `recordsize=128K` on a PostgreSQL dataset | Roughly 16x write amplification. Usually the single highest-impact tuning change available. |

## Host-role expectations

**Database hosts:** `recordsize` 8K or 16K, `atime=off`, `compression=lz4` or `zstd`,
`sync=standard`, ARC capped so it does not contend with `shared_buffers`, snapshot tooling scheduled.

**Hypervisors:** capacity headroom matters more, since every guest shares the degradation. Check for
stale guest snapshots, which pin changed blocks and consume pool space invisibly.

## Output

```markdown
## ZFS assessment: [host], [date]

### Pool
| Pool | State | Capacity | Frag | Errors | Last scrub |
|---|---|---|---|---|---|

### Healthy
### Concerns
### Issues
```

For `recordsize` findings, state the migration path as well as the target value -- the change affects
new writes only, so "set recordsize=8K" alone is not an actionable recommendation.
