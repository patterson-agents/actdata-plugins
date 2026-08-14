---
name: linux-host-tuning
description: This skill should be used when the user asks to "check the disks", "check SMART", "are the drives failing", "check drive wear", "assess the kernel", "check sysctl", "is swappiness set", "check transparent huge pages", "check the I/O scheduler", "check ulimits", or mentions nvme smart-log, smartctl, percentage_used, PLP, vm.swappiness, dirty_ratio, overcommit, THP, NUMA, or file descriptor limits on a database or storage host. Covers drive health assessment and kernel and sysctl tuning.
---

# Linux Host Tuning

Drive health and kernel parameter diagnostics for hosts running databases and storage. All commands
are read-only; changes are called out explicitly.

## Before running anything

Resolve the target host from the site inventory. See the `infrastructure-inventory` skill.

## Two independent areas

**Drive health** answers "is this hardware about to fail". It is a hardware-lifecycle question, and
the answer usually has a lead time measured in months -- which is exactly why it is worth checking
before the lead time runs out.

**Kernel tuning** answers "is this host configured for the workload on it". Defaults are chosen for
general-purpose machines and are frequently wrong for a database host.

## The findings that matter most

| Check | Why it outranks the rest |
|---|---|
| NVMe `percentage_used` above 80% | A wear-out failure is predictable and schedulable. Missing it converts planned maintenance into an outage. |
| Consumer drives without power-loss protection | An unexpected power loss can corrupt in-flight writes on a database. |
| Transparent huge pages enabled | Causes latency spikes on database workloads. One of the highest value-to-effort fixes available. |
| `vm.swappiness` at the default 60 | The host will swap out database pages under memory pressure. |
| Default 1024 file descriptor limit | Causes connection failures under load, presenting as a mysterious application error. |

## Reference material

| File | Covers |
|---|---|
| `references/disk-health.md` | NVMe SMART via nvme-cli, smartctl for NVMe and SATA, drive model identification, PLP |
| `references/kernel-and-sysctl.md` | DB-relevant sysctls with recommended values, transparent huge pages, I/O scheduler, ulimits, NUMA, system overview |

## When to hand off

| Symptom | Skill or agent |
|---|---|
| Pool-level or dataset-level storage questions | `zfs-storage` skill |
| Memory contention between ARC and `shared_buffers` | `zfs-storage` skill, ARC sizing section |
| Query-level performance after the host is tuned | `postgres-operations` skill |
| Hypervisor host rather than a bare-metal server | `proxmox-virtualization` skill |
