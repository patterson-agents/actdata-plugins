<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../docs/assets/act-wordmark-white.svg">
  <img src="../../docs/assets/act-wordmark.svg" alt="ACT Data" width="260">
</picture>

# act-platform-engineering

Assessment and operations for PostgreSQL, ZFS, Linux hosts and Proxmox VE.

![skills](https://img.shields.io/badge/skills-7-00A8E1?labelColor=003767)
![agents](https://img.shields.io/badge/agents-7-003767)
![commands](https://img.shields.io/badge/commands-9-147EC2)
![config](https://img.shields.io/badge/config-driven-00817D)
![deps](https://img.shields.io/badge/dependencies-none-58585B)

</div>

---

## Table of contents

- [What this is](#what-this-is)
- [What ships](#what-ships)
- [Skills](#skills)
- [Agents](#agents)
- [Commands](#commands)
- [Install](#install)
- [Configuration](#configuration)
- [What this plugin does NOT do](#what-this-plugin-does-not-do)
- [Layout](#layout)

## What this is

A toolkit for assessing and operating database and storage infrastructure. It carries the diagnostic
commands with their pass/fail criteria, the role-based reasoning that decides which diagnostic
matters, and the incident and runbook practice for when something is actually broken.

It ships **no environment identifiers**. No hostnames, no addresses, no database names, no service
endpoints, not even as defaults or examples. Every site-specific value comes from a settings file
you write. See [Configuration](#configuration).

That constraint is the point. A command that defaults to a plausible-looking hostname is a command
that will eventually run a diagnostic against the wrong machine and report confident findings about
it.

## What ships

| Component | Count | What it is |
|---|---|---|
| Skills | 7 | Domain knowledge: diagnostics, thresholds, and what the output means |
| Agents | 7 | Role-based reasoning for open-ended investigation |
| Commands | 9 | One-shot assessments producing structured findings |
| Scripts | 1 | A read-only ten-section triage pass over a database host |

## Skills

| Skill | What it covers |
|---|---|
| [`infrastructure-inventory`](skills/infrastructure-inventory/) | Where the site inventory lives, how to read it, and the never-invent-a-hostname rule |
| [`postgres-operations`](skills/postgres-operations/) | Performance, backups and recovery, replication and HA |
| [`zfs-storage`](skills/zfs-storage/) | Pool health, tuning for PostgreSQL, snapshot policy |
| [`linux-host-tuning`](skills/linux-host-tuning/) | Drive health and SMART, kernel and sysctl parameters |
| [`proxmox-virtualization`](skills/proxmox-virtualization/) | Cluster quorum, node health, VM hygiene, backup coverage |
| [`observability`](skills/observability/) | Coverage assessment and deciding what deserves an alert |
| [`incident-response`](skills/incident-response/) | Running an incident, plus postmortem and runbook templates |

## Agents

| Agent | When it runs |
|---|---|
| `dba` | Database-internal problems: queries, replication, backups, configuration |
| `sre` | Blast radius, time to detect and recover, single points of failure |
| `sysadmin` | Hardware, filesystems, kernel, fleet consistency, recoverability |
| `platform-engineer` | Declared state, self-service, infrastructure as code design |
| `observability-engineer` | What to measure, what to alert on, coverage gaps |
| `security-engineer` | Access control, secrets handling, patch cadence |
| `incident-responder` | An active outage, and the postmortem afterwards |

## Commands

| Command | Does |
|---|---|
| `/act-platform-engineering:triage-pg-host` | Ten-section fast read across every layer of a database host |
| `/act-platform-engineering:assess-postgres` | Performance, configuration and health |
| `/act-platform-engineering:assess-replication` | Streaming health and failover readiness |
| `/act-platform-engineering:assess-backups` | Whether recovery is actually possible |
| `/act-platform-engineering:assess-zfs` | Pool health, capacity, dataset tuning, snapshots |
| `/act-platform-engineering:assess-disks` | Drive wear, SMART, power-loss protection |
| `/act-platform-engineering:assess-kernel` | Sysctls, huge pages, I/O scheduler, ulimits |
| `/act-platform-engineering:assess-pve` | Cluster quorum, VM hygiene, backup coverage |
| `/act-platform-engineering:observability-status` | Collector coverage against the inventory |

## Install

```sh
claude plugin marketplace add patterson-agents/actdata-plugins
claude plugin install act-platform-engineering@actdata-plugins
```

From a local checkout:

```sh
claude plugin marketplace add /path/to/actdata-plugins
claude plugin install act-platform-engineering@actdata-plugins
```

## Configuration

Create `.claude/act-platform-engineering.local.md` in your project. It is gitignored by this
repository's `.gitignore` (`.claude/*.local.md`), and it must stay that way -- it holds exactly the
identifiers the plugin is designed not to carry.

```markdown
# act-platform-engineering settings

## Hosts

| Name | Role | Address | Notes |
|------|------|---------|-------|
| db-primary | primary | 10.0.0.10 | Writer |
| db-replica-1 | replica | 10.0.0.11 | Streaming |
| hv-1 | hypervisor | 10.0.0.20 | ZFS-backed |

## Databases

| Database | Host | Notes |
|----------|------|-------|
| appdb | db-primary | Production |

## Services

| Service | Endpoint | Notes |
|---------|----------|-------|
| Grafana | https://grafana.internal | Metrics |
```

Roles the commands recognise: `primary`, `replica`, `standby`, `hypervisor`, `app`,
`observability`. Free text is allowed; unrecognised roles simply are not auto-matched.

Partial entries are fine. A host with no address recorded means "this exists but I have not recorded
how to reach it", and the plugin will ask rather than guess.

> [!NOTE]
> With no settings file present, the commands ask for a target rather than assuming one. That is the
> intended behaviour, not a failure.

## What this plugin does NOT do

> [!CAUTION]
> Nothing here changes a system. Every command and script is read-only. Where a change is
> recommended, it is described for a human to apply after reading it. Do not expect a remediation
> mode.

- **No host discovery.** It does not scan a network, read SSH config, or query cloud metadata to
  populate the inventory. Host discovery is an operator decision with security consequences.
- **No credential handling.** It does not store, read, or prompt for passwords or keys. Connections
  use whatever authentication the operator's environment already provides.
- **No remediation.** It will not run `VACUUM FULL`, change a sysctl, set a ZFS property, promote a
  replica, or replace a drive.
- **No monitoring.** It assesses observability coverage; it is not itself a monitoring system and
  does not run continuously.
- **No opinion about your estate's naming.** It reads the inventory you give it.

## Layout

```text
act-platform-engineering/
  .claude-plugin/plugin.json
  README.md
  agents/
    dba.md  sre.md  sysadmin.md  platform-engineer.md
    observability-engineer.md  security-engineer.md  incident-responder.md
  commands/
    triage-pg-host.md
    assess-postgres.md  assess-replication.md  assess-backups.md
    assess-zfs.md  assess-disks.md  assess-kernel.md  assess-pve.md
    observability-status.md
  scripts/
    triage-pg-host.sh
  skills/
    infrastructure-inventory/SKILL.md
    postgres-operations/    SKILL.md + references/(3)
    zfs-storage/            SKILL.md + references/(3)
    linux-host-tuning/      SKILL.md + references/(2)
    proxmox-virtualization/ SKILL.md
    observability/          SKILL.md
    incident-response/      SKILL.md + references/(2)
```
