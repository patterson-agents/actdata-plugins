---
name: proxmox-virtualization
description: This skill should be used when the user asks to "check PVE", "Proxmox health", "how are the hypervisors", "check the VM fleet", "is the cluster quorate", "check VM backups", "are there orphaned VMs", or mentions pvecm, pvesh, pvesm, vzdump, Proxmox Backup Server, ha-manager, cluster quorum, or VM sprawl. Covers Proxmox VE cluster health, node and storage checks, VM inventory hygiene, backup configuration, and high availability.
---

# Proxmox VE

Cluster, node, and VM-fleet assessment for Proxmox VE. Read-only throughout.

## Before running anything

Resolve which hosts are hypervisors from the site inventory -- the `## Hosts` table rows whose Role
is `hypervisor`. See the `infrastructure-inventory` skill. Do not assume node names or a node count.

## Cluster level

Run on any node in the cluster:

```bash
pvecm status                                # quorum and node membership
pvesh get /nodes                            # node summary
pvesh get /cluster/resources --type vm      # VM inventory across the cluster
```

**Quorum is the finding that outranks the others.** A cluster needs more than half its votes to
permit writes. On a three-node cluster, losing one node is degraded but functional; losing two stops
all configuration writes, including the ones needed to recover. On a two-node cluster, losing either
node halts writes unless a qbit or quorum device is configured -- which is why two-node PVE clusters
are a design smell rather than a small cluster.

Confirm every node the inventory lists appears `Online`. A node missing from `pvecm status` is
already a partial outage even if the VMs on it are still running.

## Per-node checks

For each hypervisor in the inventory:

```bash
# Storage -- PVE storage is frequently ZFS-backed
zpool status
zpool list
pvesm status

# System health
dmesg | tail -50
journalctl -p err -b

# PVE itself
pveversion
systemctl --failed
```

Hand off deeper storage work to the `zfs-storage` skill and drive health to `linux-host-tuning`.
Capacity above 80% on a PVE pool degrades every VM on that node at once, so it carries more blast
radius here than on a single-purpose host.

## VM inventory hygiene

For each VM record name, ID, state, host, CPU and RAM allocation, disk size, and snapshots. Then
look for the three recurring problems:

| Problem | How it shows | Why it matters |
|---|---|---|
| Orphaned VMs | Powered off for months, no clear owner | Consuming disk and snapshot space; nobody will notice if they break |
| Stale snapshots | Creation dates months old | A VM snapshot pins every changed block. On ZFS this quietly eats the pool. |
| Resource overcommit | Allocated RAM exceeds physical, without ballooning | Works until several VMs get busy simultaneously, then everything swaps at once |

Overcommit is not automatically wrong -- it is standard practice with ballooning enabled and a
workload that does not peak together. It becomes a finding when the allocation exceeds physical RAM
*and* ballooning is off, because then there is no mechanism to reclaim.

## Backup configuration

```bash
cat /etc/pve/jobs.cfg 2>/dev/null       # vzdump jobs
```

Also check for Proxmox Backup Server integration in the storage list.

Answer three questions explicitly, because "backups are configured" answers none of them:

1. Which VMs are actually covered? Compare the job's selection against the full VM list.
2. Where do the backups land, and is that destination on the same pool as the source?
3. When did each VM last back up *successfully*?

A vzdump job that has been failing for weeks still appears in `jobs.cfg` looking healthy. A backup
written to the same ZFS pool as the VM protects against deletion but not against pool loss.

## High availability

```bash
ha-manager status
```

HA requires shared storage or replication. Check the prerequisite is genuinely met rather than
trusting that HA is enabled -- HA configured without a working shared storage backend fails at
exactly the moment it is needed.

## Reporting

Structure findings as cluster state, then per-node table, then VM inventory summary, then backup
coverage, then the same three buckets every assessment in this plugin ends with:

| Bucket | Contains |
|---|---|
| Healthy | Checked, no action needed. Include it: silence reads as "not checked". |
| Concerns | Needs investigation. Say what to check next. |
| Issues | Needs remediation. Say what to do. |

Every item carries the output that produced it.

## When to hand off

| Symptom | Skill |
|---|---|
| Pool health, capacity, ZFS tuning | `zfs-storage` |
| Drive wear, SMART, controller errors | `linux-host-tuning` |
| A guest database's own performance | `postgres-operations` |
| A node down right now | `incident-response` |
