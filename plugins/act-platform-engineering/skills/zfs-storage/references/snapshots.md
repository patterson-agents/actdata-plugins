# ZFS snapshots

---

## 1. Current snapshot state

```bash
# All snapshots, oldest first
zfs list -t snapshot -o name,creation,used,refer -s creation

# Count per dataset
zfs list -t snapshot -o name | awk -F@ '{print $1}' | sort | uniq -c | sort -rn
```

An empty result means zero rollback capability. That is a finding.

## 2. Snapshot tooling

```bash
# zfs-auto-snapshot
dpkg -l 2>/dev/null | grep zfs-auto-snapshot
which zfs-auto-snapshot 2>/dev/null

# sanoid -- preferred for production
dpkg -l 2>/dev/null | grep sanoid
which sanoid 2>/dev/null
cat /etc/sanoid/sanoid.conf 2>/dev/null

# Scheduled jobs
crontab -l 2>/dev/null | grep -i 'snap\|sanoid\|syncoid'
sudo crontab -l 2>/dev/null | grep -i 'snap\|sanoid\|syncoid'
systemctl list-timers --all 2>/dev/null | grep -i 'snap\|sanoid\|syncoid'
```

**Green:** sanoid or zfs-auto-snapshot with a defined retention policy, snapshots being created on
schedule.

**Red:** No tooling. Manual snapshots only, or none at all.

Check that snapshots are still being *created*, not merely that a tool is installed. A sanoid unit
that has been failing for months leaves a plausible-looking config file and a stale newest snapshot.
Compare the newest `creation` timestamp against the configured frequency.

## 3. Space consumption

```bash
# Total space held by snapshots
zfs list -t snapshot -o used -p | awk 'NR>1 {sum+=$1} END {printf "Total snapshot space: %.1f GB\n", sum/1073741824}'

# Worst offenders
zfs list -o name,usedbysnapshots -r | sort -k2 -h | tail -10
```

**Green:** Snapshot space is a small fraction of the pool, under 20%.

**Red:** Snapshots consuming a large share. Either retention is too long, or data churn is high
enough that each snapshot pins a lot of superseded blocks.

On a database dataset, churn is high by definition -- every vacuum and every update rewrites blocks
that snapshots then retain. Snapshot space on a Postgres dataset grows faster than intuition
suggests, and it is a common cause of a pool crossing the 80% capacity cliff.

## 4. What snapshots are and are not

A snapshot is a rollback mechanism, not a backup. It lives in the same pool as the data it protects.
A pool loss, a controller failure, or a host fire takes the snapshots with it.

For snapshots to count toward a backup strategy they must be replicated off the host, with
`zfs send`/`zfs receive` or syncoid. Check for that separately:

```bash
crontab -l 2>/dev/null | grep -i 'syncoid\|zfs send'
systemctl list-timers --all 2>/dev/null | grep -i syncoid
```

> [!NOTE]
> A snapshot of a running PostgreSQL data directory is crash-consistent, not
> application-consistent. Postgres recovers from it the same way it recovers from a power loss,
> which works, but it is not a substitute for `pg_basebackup` plus WAL archiving. See the
> `postgres-operations` skill's backup reference.
