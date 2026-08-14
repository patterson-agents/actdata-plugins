---
description: Assess Proxmox VE cluster health, node storage, VM inventory hygiene, backup coverage and HA
argument-hint: "[node]"
allowed-tools: Read, Bash, Grep, Glob
---

# Assess Proxmox VE

Cluster quorum, per-node health, VM fleet hygiene, and whether the guests are actually backed up.

## Resolve the cluster

Read `.claude/act-platform-engineering.local.md` and take every `## Hosts` row whose Role is
`hypervisor`. A single node from `$ARGUMENTS` overrides. If no hypervisors are recorded, ask.

The node count matters for the quorum assessment, so take it from the inventory rather than from
whatever `pvecm` currently reports -- a node missing from `pvecm status` is exactly the finding you
are looking for.

## Cluster level

Run on any node:

```bash
pvecm status
pvesh get /nodes
pvesh get /cluster/resources --type vm
```

**Quorum outranks everything else.** A cluster needs more than half its votes to permit configuration
writes. On three nodes, losing one is degraded but functional; losing two stops all writes including
the ones needed to recover. A two-node cluster without a quorum device halts on either node's
failure.

Confirm every inventory node appears `Online`.

## Per node

```bash
zpool status && zpool list      # PVE storage is frequently ZFS-backed
pvesm status
pveversion
systemctl --failed
dmesg | tail -50
journalctl -p err -b
```

Capacity above 80% degrades every guest on that node simultaneously, so it carries more blast radius
here than on a single-purpose host.

## VM inventory hygiene

Record name, ID, state, host, CPU and RAM allocation, disk size and snapshots for each guest. Then
look for:

| Problem | Why it matters |
|---|---|
| Orphaned VMs -- powered off for months, no owner | Consuming disk and snapshot space; nobody notices when they break |
| Stale snapshots, months old | Each pins every changed block since creation. On ZFS this quietly eats the pool. |
| Overcommit without ballooning | Works until several guests get busy together, then everything swaps at once |

Overcommit is standard practice *with* ballooning enabled and workloads that do not peak together. It
becomes a finding when allocation exceeds physical RAM and ballooning is off, because nothing can
then reclaim.

## Backup coverage

```bash
cat /etc/pve/jobs.cfg 2>/dev/null
```

Answer three questions explicitly, because "backups are configured" answers none of them:

1. **Which guests are covered?** Compare the job selection against the full VM list. Report the
   uncovered ones by name.
2. **Where do backups land?** A backup on the same pool as its source protects against deletion only.
3. **When did each guest last succeed?** A job failing for weeks still looks healthy in `jobs.cfg`.

## High availability

```bash
ha-manager status
```

HA requires shared storage or replication. Verify the prerequisite is genuinely met -- HA enabled
without a working shared backend fails precisely when it is needed.

## Output

```markdown
## PVE cluster assessment: [date]

### Cluster
- Nodes online: [n of inventory total]
- Quorate: [yes/no]
- Version: [version]

### Nodes
| Node | Version | Pool health | Capacity | Failed units |
|---|---|---|---|---|

### VM inventory
- Total / running / stopped / HA-enabled

### Backup coverage
- Guests with no recent successful backup: [names]

### Healthy
### Concerns
### Issues
```

## Follow-up

- Pool detail: `/act-platform-engineering:assess-zfs`
- Drive health: `/act-platform-engineering:assess-disks`
