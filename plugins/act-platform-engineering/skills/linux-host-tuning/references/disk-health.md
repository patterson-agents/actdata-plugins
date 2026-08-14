# Disk health

Read-only diagnostics. Requires `nvme-cli` and `smartmontools`.

---

## 1. NVMe health via nvme-cli

```bash
# apt install nvme-cli   (if absent)

nvme list

for dev in /dev/nvme?; do
  echo "=== $dev ==="
  nvme smart-log "$dev"
  echo
done
```

**Key fields:**

| Field | Threshold |
|---|---|
| `percentage_used` | Drive wear. Above 80% is concerning; above 95% is urgent. |
| `available_spare` vs `available_spare_threshold` | When spare drops below threshold the drive is end-of-life. |
| `critical_warning` | Any non-zero value is an alert. |
| `temperature` | Sustained above 70C is concerning. |
| `media_errors`, `num_err_log_entries` | Should be zero. |

`percentage_used` can exceed 100. It is a wear estimate against the rated endurance, not a
percentage of remaining life, and a drive at 110% has not stopped working -- it is past its warranty
endurance and should be scheduled for replacement.

In a mirrored or raidz set, drives bought together and written identically wear out together. If one
drive reads 85%, check its siblings and expect similar numbers. Correlated failure during a resilver
is how redundant pools are lost.

## 2. SMART via smartctl

```bash
# apt install smartmontools   (if absent)

for dev in /dev/nvme?n1; do
  echo "=== $dev ==="
  smartctl -a "$dev"
  echo
done

for dev in /dev/sd?; do
  echo "=== $dev ==="
  smartctl -a "$dev"
  echo
done
```

`smartctl` reports the same wear figure as `Percentage Used` and adds vendor attributes that
`nvme smart-log` omits.

## 3. Drive model identification

```bash
lsblk -d -o NAME,MODEL,SIZE,ROTA,TRAN,REV
```

Look up each model. What matters:

- **Consumer versus enterprise.** Consumer NVMe has lower endurance ratings and, critically, usually
  lacks power-loss protection.
- **Power-loss protection (PLP).** Enterprise drives carry capacitors that flush the write buffer on
  power loss. Consumer drives do not.
- **TBW rating** against current usage, to project remaining life.
- **Known firmware issues** for the specific revision in the `REV` column.

### Why PLP matters on a database host

Without PLP, an unexpected power loss can corrupt writes the drive has already acknowledged but not
yet committed to flash. PostgreSQL's durability guarantee assumes `fsync` means the data is safe. If
the drive lies about that, the write-ahead log's guarantee is broken and crash recovery can produce
a corrupt database.

ZFS mitigates this partially -- checksums detect the corruption and the ZIL provides some protection
-- but detection is not prevention. Consumer drives under a production database, with no UPS, is a
data-integrity finding worth recording even when everything currently looks healthy.

The mitigations, in order of preference: enterprise drives with PLP; failing that, a tested UPS with
automatic graceful shutdown; failing that, an explicit accepted risk with a documented recovery
plan.
