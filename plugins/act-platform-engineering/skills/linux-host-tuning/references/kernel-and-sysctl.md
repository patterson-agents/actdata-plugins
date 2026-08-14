# Kernel and sysctl tuning

Read-only diagnostics with recommended values. Applying changes is called out at the end.

---

## 1. Current values for DB-relevant sysctls

```bash
for param in \
  vm.swappiness \
  vm.dirty_ratio \
  vm.dirty_background_ratio \
  vm.dirty_expire_centisecs \
  vm.dirty_writeback_centisecs \
  vm.overcommit_memory \
  vm.overcommit_ratio \
  vm.min_free_kbytes \
  vm.zone_reclaim_mode \
  vm.nr_hugepages \
  kernel.sched_migration_cost_ns \
  kernel.sched_autogroup_enabled \
  net.core.somaxconn \
  net.ipv4.tcp_max_syn_backlog \
  net.ipv4.tcp_tw_reuse \
  net.ipv4.tcp_fin_timeout \
  fs.file-max
do
  val=$(sysctl -n "$param" 2>/dev/null)
  printf "%-45s %s\n" "$param" "${val:-NOT SET}"
done
```

**Recommended for PostgreSQL on NVMe:**

| Parameter | Recommended | Default | Why |
|---|---|---|---|
| `vm.swappiness` | `1` | `60` | Avoid swapping database pages. Do not use `0` -- it makes the OOM killer more aggressive. |
| `vm.dirty_ratio` | `10` | `20` | Cap dirty page accumulation to prevent I/O stalls at checkpoint. |
| `vm.dirty_background_ratio` | `3` | `10` | Start background flushing earlier, smoothing the write curve. |
| `vm.overcommit_memory` | `2` | `0` | Stops the OOM killer selecting a Postgres backend. |
| `vm.overcommit_ratio` | `80`-`90` | `50` | With `overcommit_memory=2`, the allocatable share of RAM. |
| `vm.min_free_kbytes` | `65536`+ | varies | Reserve for kernel allocations under pressure. |
| `vm.zone_reclaim_mode` | `0` | `0` | Prevents NUMA zone reclaim stalls. Verify rather than assume. |
| `kernel.sched_migration_cost_ns` | `5000000` | `500000` | Reduces needless CPU migration of database processes. |
| `kernel.sched_autogroup_enabled` | `0` | `1` | Autogrouping is for desktops. |
| `net.core.somaxconn` | `4096` | `4096` | Socket backlog for connection-heavy workloads. |
| `fs.file-max` | `2097152`+ | varies | Enough descriptors for connections, WAL and data files. |

> [!CAUTION]
> `vm.overcommit_memory=2` with a badly chosen `overcommit_ratio` causes allocation failures on a
> host that has free RAM. Compute the resulting limit (`swap + ratio% of RAM`) and confirm it exceeds
> the real peak usage of `shared_buffers` plus `work_mem` times connections, before applying it.

On a host also running ZFS, `vm.min_free_kbytes` interacts with ARC reclaim. See the `zfs-storage`
skill's ARC sizing section.

## 2. Transparent huge pages

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag
```

**Green:** `[never]` for both.

**Red:** `[always]` or `[madvise]`.

THP makes the kernel compact memory into 2MB pages in the background. For a database, that produces
latency spikes at unpredictable moments -- the classic symptom is a query that normally takes 10ms
occasionally taking several seconds with no change in plan or load.

To disable:

```bash
# Until reboot
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

Permanent: add `transparent_hugepage=never` to the kernel command line in the bootloader
configuration, or ship a systemd unit that writes both files at boot. The temporary form silently
reverts on the next reboot, so verify after any maintenance.

This is distinct from *explicit* huge pages (`vm.nr_hugepages` and Postgres `huge_pages=on`), which
are beneficial. Disable transparent huge pages; consider explicit ones.

## 3. I/O scheduler

```bash
for dev in /sys/block/nvme* /sys/block/sd*; do
  [ -f "$dev/queue/scheduler" ] && echo "$(basename "$dev"): $(cat "$dev/queue/scheduler")"
done
```

**Green:** `[none]` or `[mq-deadline]` for NVMe.

**Red:** `[bfq]` or `[cfq]` on NVMe. Those schedulers reorder requests to reduce seek time on
spinning disks. NVMe has no seek time, so the reordering is pure overhead.

## 4. ulimits for PostgreSQL

```bash
PG_PID=$(pgrep -o postgres 2>/dev/null || pgrep -o postmaster 2>/dev/null)
if [ -n "$PG_PID" ]; then
  echo "=== Limits for PID $PG_PID ==="
  cat "/proc/$PG_PID/limits"
fi

systemctl show 'postgresql*' 2>/dev/null | grep -i 'limitnofile\|limitas\|limitnproc\|limitmemlock'
```

**Green:** `Max open files` at least 65536, `Max processes` at least 4096.

**Red:** The 1024 default. Under load this surfaces as connection failures or "too many open files"
in the Postgres log, which looks like an application bug rather than a host misconfiguration.

Read the limits from `/proc/<pid>/limits` rather than running `ulimit -n` in a shell. The shell
shows your session's limits; the systemd unit's `LimitNOFILE` is what Postgres actually got, and the
two frequently differ.

## 5. NUMA topology

```bash
numactl --hardware 2>/dev/null || echo "numactl not installed"
lscpu | grep -i numa
```

With more than one NUMA node, memory access cost depends on which node allocated it. Ensure
`vm.zone_reclaim_mode = 0` at minimum; pinning Postgres to a single node is better where the
working set fits.

## 6. System overview

```bash
echo "=== OS ==="
head -5 /etc/os-release
uname -r

echo "=== Uptime ==="
uptime

echo "=== CPU ==="
lscpu | grep -E 'Model name|Socket|Core|Thread|NUMA'

echo "=== Memory ==="
free -h

echo "=== Disks ==="
lsblk -d -o NAME,MODEL,SIZE,ROTA,TRAN

echo "=== ZFS ==="
zfs version 2>/dev/null || modinfo zfs 2>/dev/null | grep -i version
```

## Applying changes

Sysctl changes belong in a file under `/etc/sysctl.d/`, not typed into a running shell. A value set
with `sysctl -w` is lost at reboot, and a host that reverts its tuning during an unrelated
maintenance window produces a performance regression nobody connects to the reboot.

```bash
# Example: /etc/sysctl.d/30-postgresql.conf
# Apply with: sysctl --system
```

Change one parameter at a time on a production host, and record the before and after. Several
simultaneous changes make it impossible to attribute either an improvement or a regression.
