---
description: "Report observability coverage across the fleet: collectors, plugins, dashboards, streaming and log aggregation"
argument-hint: "[host]"
allowed-tools: Read, Bash, Grep, Glob
---

# Observability status

How much of the estate is genuinely observable, reported against the inventory rather than as a
count.

## Resolve the fleet

Read `.claude/act-platform-engineering.local.md`. Every `## Hosts` row is the denominator; the
`## Services` table supplies the aggregation endpoints. Without the inventory, "the collector is
running on six hosts" is not a coverage statement.

Restrict to a single host if given in `$ARGUMENTS`.

## Aggregation layer

Check reachability, configured datasources and their health, dashboard inventory, and provisioning
errors:

```bash
journalctl -u grafana-server | tail -50
```

## Per-host collector state

```bash
systemctl is-active netdata
systemctl status netdata --no-pager | head -10
curl -s http://localhost:19999/api/v1/info | jq '.version, .uptime'
```

Then check the plugins that matter **for that host's role**, taken from the inventory:

| Role | Plugins expected |
|---|---|
| Database | Database plugin, plus the storage plugin for its filesystem |
| Storage or hypervisor | ZFS, disk, system |
| All | CPU, memory, network, disk I/O, systemd unit state |

## The partial-coverage trap

A database host running a collector **without its database plugin** counts as covered on a coverage
table and tells you nothing about the database. This is the most common partial failure and it is
invisible unless plugins are checked per role.

Report it as a gap, not as coverage.

## Streaming and logs

- Is there a parent collector, and are all children reporting to it? Without one, diagnosis means
  visiting each host individually, which is what nobody does at 3am.
- Is there centralised log aggregation? Without it, troubleshooting is SSH and grep across the fleet.

## Output

```markdown
## Observability status: [date]

### Aggregation
- Reachable: [yes/no] | Version: [v] | Datasources: [list with health]
- Dashboards: [count, key ones named]

### Collector coverage: [n of m hosts from inventory]
| Host | Role | Collector | Version | Role plugins present |
|---|---|---|---|---|

### Streaming
- Parent: [host or none] | Children reporting: [n of m]

### Centralised logs
- Aggregator: [tool or "not deployed"] | Hosts forwarding: [n]

### Gaps
- Hosts with no collector: [names]
- Hosts missing a role-relevant plugin: [names]
- Dashboards that should exist and do not: [named]
```

Name specific hosts and specific dashboards. "Coverage is at 70%" is not actionable; "these four
hosts have no collector and there is no replication-lag dashboard" is.

## Follow-up

- What to alert on and what to leave on a dashboard: the `observability` skill
- Metric design by domain: the `observability-engineer` agent
