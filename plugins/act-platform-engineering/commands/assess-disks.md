---
description: Check drive health via SMART and NVMe telemetry, including wear, spare capacity and power-loss protection
argument-hint: "[host]"
allowed-tools: Read, Bash, Grep, Glob
---

# Assess disks

Drive health and remaining life. This is a lead-time question: most drive failures are predictable
months ahead, and the value of the check is entirely in acting inside that window.

## Resolve the target

Host from `$ARGUMENTS`, else from `.claude/act-platform-engineering.local.md`, else ask.

## Run the checks

Load the `linux-host-tuning` skill and work through `references/disk-health.md`.

1. `nvme list` and `nvme smart-log` per device
2. `smartctl -a` per device, for NVMe and any SATA drives
3. `lsblk -d -o NAME,MODEL,SIZE,ROTA,TRAN,REV` for model identification

## Key fields

| Field | Threshold |
|---|---|
| `percentage_used` | Above 80% concerning, above 95% urgent |
| `available_spare` vs threshold | Below threshold means end of life |
| `critical_warning` | Any non-zero value |
| `temperature` | Sustained above 70C |
| `media_errors`, `num_err_log_entries` | Should be zero |

`percentage_used` can exceed 100. It measures wear against rated endurance, not remaining life; a
drive past 100% still works but is beyond its warranty endurance.

## Check the siblings

**When one drive shows high wear, check every drive in the same vdev or array.** Drives purchased
together and written identically wear together. Correlated failure during a resilver is how redundant
pools are lost, and it is invisible if only the worst drive is examined.

Report wear across the whole set, not just the outlier.

## Power-loss protection

From the model numbers, determine whether the drives are consumer or enterprise and whether they
carry power-loss protection.

Consumer drives without PLP under a production database are a data-integrity finding even when
everything is currently healthy. Without PLP, an unexpected power loss can corrupt writes the drive
has already acknowledged, which breaks the durability guarantee PostgreSQL's write-ahead log depends
on.

Record it with its mitigations in order: enterprise drives with PLP; failing that, a tested UPS with
automatic graceful shutdown; failing that, an explicitly accepted risk with a recovery plan.

## Output

```markdown
## Disk health: [host], [date]

| Device | Model | Class | PLP | Used % | Spare | Errors | Temp |
|---|---|---|---|---|---|---|---|

### Healthy
### Concerns
### Issues
```

For any wear finding, state the implied replacement window. A drive at 84% is a scheduling decision;
saying so is part of the finding.
