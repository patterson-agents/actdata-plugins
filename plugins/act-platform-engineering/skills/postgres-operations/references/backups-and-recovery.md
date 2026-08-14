# PostgreSQL backups and recovery

Read-only diagnostics with green/red criteria. Resolve the target host from the site inventory
before running anything here.

---

## 1. WAL archiving configuration

```bash
psql -U postgres -c "
SELECT name, setting
FROM pg_settings
WHERE name IN (
  'archive_mode', 'archive_command', 'archive_timeout',
  'wal_level', 'max_wal_senders', 'max_replication_slots'
)
ORDER BY name;
"
```

**Green:** `archive_mode = on`, `wal_level = replica` or `logical`, a sensible `archive_command`.

**Red:** `archive_mode = off` means no point-in-time recovery capability at all. `wal_level =
minimal` means replication is impossible.

An `archive_command` that always succeeds (`archive_command = 'true'`) is worse than none -- it
tells Postgres the WAL is safely archived when it has been discarded.

## 2. WAL archive lag

```bash
psql -U postgres -c "
SELECT
  last_archived_wal,
  last_archived_time,
  last_failed_wal,
  last_failed_time,
  now() - last_archived_time AS archive_lag
FROM pg_stat_archiver;
"
```

**Green:** `last_failed_wal` empty, `archive_lag` under a few minutes.

**Red:** `last_failed_wal` populated, or a large `archive_lag`. A failing archive command causes WAL
to accumulate in `pg_wal` until the filesystem fills, which stops the database.

## 3. Base backup schedule

```bash
# Cron
crontab -l 2>/dev/null | grep -i 'pg_basebackup\|pgbackrest\|barman'
sudo crontab -l 2>/dev/null | grep -i 'pg_basebackup\|pgbackrest\|barman'

# systemd timers
systemctl list-timers --all 2>/dev/null | grep -i 'backup\|pgbackrest\|barman'

# pgBackRest, if present
which pgbackrest 2>/dev/null && pgbackrest info
```

**Green:** Scheduled base backups **and** a restore process that has actually been tested.

**Red:** No base backup schedule.

> [!IMPORTANT]
> WAL shipping alone is not a backup strategy. WAL replays forward from a base backup; without one
> there is nothing to replay onto. A broken WAL chain with no base backup means total data loss.

A backup that has never been restored is a hypothesis, not a backup. If no restore test is on
record, that is a finding in its own right regardless of what the schedule says.

## 4. Replication slots

```bash
psql -U postgres -c "
SELECT
  slot_name,
  slot_type,
  active,
  restart_lsn,
  confirmed_flush_lsn,
  pg_size_pretty(
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
  ) AS retained_wal
FROM pg_replication_slots;
"
```

**Green:** Every slot `active = true`, `retained_wal` small (under 1GB).

**Red:** An inactive slot retaining a large amount of WAL.

This is one of the few Postgres failure modes that takes down a healthy primary. An inactive slot
prevents WAL cleanup forever -- the disk fills, and the database stops. A slot left behind by a
decommissioned replica is the classic cause. Check `max_slot_wal_keep_size` (PostgreSQL 13+), which
caps the damage by invalidating a slot rather than filling the disk.
