# ZFS pool health

Read-only diagnostics with green/red criteria.

---

## 1. Pool status

```bash
zpool status -v
```

**Green:** `state: ONLINE`, every device `ONLINE`, `errors: No known data errors`, a recent scrub
with zero errors.

**Red:**

| Signal | Meaning |
|---|---|
| `state: DEGRADED` | A drive has failed or been removed. Redundancy is reduced or gone. |
| `CKSUM` errors | Silent data corruption. ZFS caught and repaired it, but the drive is failing. |
| `READ` / `WRITE` errors | I/O failures at the device level. |
| No scrub history, or a scrub older than 30 days | Corruption may be present and undetected. |

Non-zero `CKSUM` on a single device is the earliest warning of a dying drive, and it is easy to
overlook because the pool still reports `ONLINE` and the data is intact. Treat it as a replace-soon
signal, not a curiosity.

## 2. Capacity and fragmentation

```bash
zpool list -o name,size,alloc,free,cap,frag,health
```

**Green:** `CAP` under 75%, `FRAG` under 50%.

**Red:** `CAP` above 80% degrades performance significantly -- copy-on-write needs free space to
write into. Above 90% is an emergency. `FRAG` above 60% on non-SSD pools is a concern.

ZFS performance does not degrade gracefully with capacity; it falls off a cliff. A pool at 85% can
be dramatically slower than the same pool at 70%, with no other change. When a database host slows
down for no apparent reason, check pool capacity before profiling queries.

## 3. Dataset space consumption

```bash
zfs list -o name,used,avail,refer,mountpoint,compressratio -r -t filesystem
```

`compressratio` is worth reading even when not investigating space. A ratio near `1.00x` on a
dataset holding compressible data means compression is off, which is free performance left on the
table.

## 4. Pool topology

```bash
zpool status | head -30
```

**What to look for:**

| Layout | Assessment |
|---|---|
| `mirror` | Good. Tolerates one drive failure per vdev, fastest resilver. |
| `raidz1` | Reasonable for 3+ drives. Tolerates one failure. |
| `raidz2` | Better. Tolerates two failures. |
| No redundancy label (plain stripe) | **Critical risk.** Any single drive failure destroys the entire pool. |
| Mixed vdev sizes | Unbalanced I/O; ZFS fills vdevs proportionally to free space. |

A striped pool with no redundancy under a production database is a finding that outranks everything
else in an assessment, however healthy the pool currently reports.

## 5. Scrub schedule

```bash
crontab -l 2>/dev/null | grep -i scrub
sudo crontab -l 2>/dev/null | grep -i scrub
systemctl list-timers --all 2>/dev/null | grep -i scrub

# Last scrub result
zpool status | grep -A3 'scan:'
```

**Green:** A monthly scrub schedule, last scrub completed with zero errors.

**Red:** No scrub schedule, or a scrub that has never run.

A scrub is what makes ZFS checksums useful. Without one, corruption is only discovered when
something reads the affected block -- which for cold data may be during a restore, when the good
copy is already gone.
