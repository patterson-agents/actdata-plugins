---
description: Check kernel and sysctl tuning, transparent huge pages, I/O scheduler and ulimits on a database host
argument-hint: "[host]"
allowed-tools: Read, Bash, Grep, Glob
---

# Assess kernel and sysctl

Whether the host is configured for the workload running on it. Defaults are chosen for
general-purpose machines and are frequently wrong for a database.

## Resolve the target

Host from `$ARGUMENTS`, else from `.claude/act-platform-engineering.local.md`, else ask.

## Run the checks

Load the `linux-host-tuning` skill and work through `references/kernel-and-sysctl.md`.

1. Current values for the DB-relevant sysctls
2. Transparent huge pages, both `enabled` and `defrag`
3. I/O scheduler per block device
4. ulimits as seen by the running database process
5. NUMA topology
6. System overview: OS, kernel, CPU, memory, disks

## Highest value findings

| Finding | Why |
|---|---|
| Transparent huge pages enabled | Causes unpredictable multi-second latency spikes on queries that normally take milliseconds. Highest value-to-effort fix available. |
| `vm.swappiness` at the default 60 | The host will swap database pages under pressure. |
| Default 1024 file descriptor limit | Surfaces as application connection errors, so it is usually misdiagnosed as an application bug. |
| `bfq` or `cfq` scheduler on NVMe | Seek optimisation on a device with no seek time. Pure overhead. |
| Values set with `sysctl -w` only | Revert at the next reboot, producing a regression nobody connects to the restart. |

## Read the limits correctly

Take ulimits from `/proc/<pid>/limits` for the running database process, not from `ulimit -n` in your
shell. The shell reports your session; the systemd unit's `LimitNOFILE` is what the database actually
received, and the two commonly differ.

## Check persistence, not just current value

For every parameter that is correct, confirm it is written under `/etc/sysctl.d/` (or the equivalent
persistent mechanism). A correct value that exists only in the running kernel is a finding, because
it will silently disappear during unrelated maintenance.

Same for transparent huge pages: the `echo never` form reverts at boot. Persistent configuration
means a kernel command-line parameter or a systemd unit.

## Interactions to flag

- `vm.overcommit_memory=2` with a badly chosen `overcommit_ratio` causes allocation failures on a
  host with free RAM. Compute the resulting limit and compare it against real peak usage before
  recommending it.
- On a ZFS host, `vm.min_free_kbytes` interacts with ARC reclaim, and `shared_buffers` cannot be
  sized from total RAM alone. Hand off to `/act-platform-engineering:assess-zfs`.

## Output

```markdown
## Kernel and sysctl: [host], [date]

| Parameter | Current | Recommended | Persistent? |
|---|---|---|---|

### Healthy
### Concerns
### Issues
```

Recommend one change at a time on a production host, and say so. Several simultaneous changes make
both improvements and regressions unattributable.
