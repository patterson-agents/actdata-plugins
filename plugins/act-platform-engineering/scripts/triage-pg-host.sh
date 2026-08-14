#!/usr/bin/env bash
# =============================================================================
# triage-pg-host.sh
#
# A fast read on a PostgreSQL host: system, memory, storage, drive health,
# database, replication, WAL archiving, dataset tuning and kernel parameters.
# Ten read-only sections, no arguments required beyond the database name.
#
# Run it when sitting down to investigate anything, or as a morning check.
#
# Usage:
#   triage-pg-host.sh [database]
#
#   Locally:   ./triage-pg-host.sh mydb
#   Remotely:  ssh <host> "bash -s" -- mydb < triage-pg-host.sh
#
#   Capture for review:
#     ssh <host> "bash -s" -- mydb < triage-pg-host.sh > triage-$(date +%Y%m%d-%H%M).log
#
# The database name may also come from the PGDATABASE environment variable.
# If neither is set, the database-specific sections are skipped and the rest
# still run -- a host-level triage is useful even without database access.
#
# This script only reads. It runs no DDL, changes no settings, and writes
# nothing outside its own stdout.
# =============================================================================

# Individual commands are expected to fail on hosts that lack a given tool.
# Continue regardless and report what could not be read.
set +e

DB="${1:-${PGDATABASE:-}}"
PSQL="sudo -u postgres psql -At"

section() {
  echo ""
  echo "============================================================"
  echo "  $1"
  echo "============================================================"
}

section "1. System identity"
hostname
head -3 /etc/os-release 2>/dev/null
uname -r
uptime

section "2. Memory and CPU"
free -h
echo ""
lscpu | grep -E 'Model name|Socket|Core|Thread|NUMA'

section "3. ZFS pool status"
zpool status -v 2>/dev/null || echo "(ZFS not available on this host)"
echo ""
zpool list 2>/dev/null

section "4. Drive health (NVMe)"
nvme list 2>/dev/null || echo "(nvme-cli not installed)"
echo ""
# Enumerate whatever NVMe controllers exist rather than assuming a device count.
for dev in /dev/nvme[0-9]*; do
  case "$dev" in
    *n[0-9]*) continue ;;   # namespaces, not controllers
  esac
  [ -e "$dev" ] || continue
  echo "--- $dev ---"
  nvme smart-log "$dev" 2>/dev/null \
    | grep -E 'critical_warning|temperature|percentage_used|available_spare|media_errors' \
    || echo "(could not read SMART)"
done

section "5. PostgreSQL version and database size"
$PSQL -c "SELECT version();" 2>/dev/null || echo "(PostgreSQL not reachable)"
if [ -n "$DB" ]; then
  $PSQL -d "$DB" -c "SELECT pg_size_pretty(pg_database_size('$DB'));" 2>/dev/null
else
  echo "(no database given; pass one as \$1 or set PGDATABASE)"
fi

section "6. Active connections"
$PSQL -c "SELECT state, count(*) FROM pg_stat_activity WHERE pid <> pg_backend_pid() GROUP BY state ORDER BY count DESC;" 2>/dev/null

section "7. Replication status (as seen from a primary)"
$PSQL -c "SELECT client_addr, state, sync_state, pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS replay_lag_bytes, replay_lag FROM pg_stat_replication ORDER BY client_addr;" 2>/dev/null
echo ""
echo "In recovery (true means this host is a replica):"
$PSQL -c "SELECT pg_is_in_recovery();" 2>/dev/null

section "8. WAL archive status"
$PSQL -c "SELECT last_archived_wal, last_archived_time, last_failed_wal, last_failed_time, now() - last_archived_time AS archive_lag FROM pg_stat_archiver;" 2>/dev/null
echo ""
echo "Replication slots:"
$PSQL -c "SELECT slot_name, slot_type, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal FROM pg_replication_slots;" 2>/dev/null

section "9. ZFS dataset properties (PostgreSQL data)"
PG_DATASETS=$(zfs list -H -o name,mountpoint 2>/dev/null | grep -iE 'postgres|pgdata|pgsql' | awk '{print $1}')
if [ -n "$PG_DATASETS" ]; then
  for ds in $PG_DATASETS; do
    echo "--- $ds ---"
    zfs get recordsize,compression,atime,logbias,sync,primarycache "$ds" 2>/dev/null
  done
else
  echo "(no datasets matched postgres/pgdata/pgsql; check 'zfs list' manually)"
fi

section "10. Key sysctls and transparent huge pages"
for param in vm.swappiness vm.dirty_ratio vm.dirty_background_ratio vm.overcommit_memory kernel.sched_autogroup_enabled; do
  val=$(sysctl -n "$param" 2>/dev/null)
  printf "%-45s %s\n" "$param" "${val:-NOT SET}"
done
echo ""
echo "THP enabled: $(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null)"
echo "THP defrag:  $(cat /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null)"

section "Triage complete"
cat <<'ANOMALIES'
Review the output above. Anomalies worth flagging:

  - Pool state not ONLINE, or non-zero CKSUM/READ/WRITE counts
  - recordsize=128K on a PostgreSQL dataset (roughly 16x write amplification)
  - sync=disabled on a database dataset (loses committed transactions on power loss)
  - Pool capacity above 80% (copy-on-write performance degrades sharply)
  - NVMe percentage_used above 80%, or critical_warning non-zero
  - More than a handful of idle-in-transaction sessions (blocks autovacuum)
  - Replication state other than streaming, or replay_lag above 30s
  - last_failed_wal populated (WAL is not reaching the archive)
  - An inactive replication slot retaining WAL (will fill the disk)
  - vm.swappiness at the default 60
  - THP not [never]
ANOMALIES
