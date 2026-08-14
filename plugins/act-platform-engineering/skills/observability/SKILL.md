---
name: observability
description: This skill should be used when the user asks "where are we on the observability rollout", "is Netdata up on all servers", "check Grafana", "observability status", "what are we not monitoring", "do we have centralized logs", "what should we alert on", or mentions Netdata, Grafana, Zabbix, Prometheus, dashboards, metric coverage, log aggregation, or monitoring blind spots. Covers assessing observability coverage across a fleet and deciding what is worth monitoring.
---

# Observability

Assessing how much of an estate is actually observable, and closing the gaps in a sensible order.

## Before running anything

Resolve the fleet from the site inventory -- every row of `## Hosts`, plus the `## Services` table
for the observability endpoints themselves. See the `infrastructure-inventory` skill. The
denominator for coverage is the host count in the inventory; without it, "Netdata is running on six
hosts" means nothing.

## The core question

Coverage is not "is the monitoring tool installed". It is **"if this broke right now, would we find
out, and would we be able to tell why?"**

Three failure modes, in order of how often they bite:

1. **No signal.** The host is not monitored at all. A blind spot.
2. **Signal nobody sees.** Metrics are collected but no dashboard or alert surfaces them. Discovered
   during an incident, when someone finds the graph that was showing the problem for a week.
3. **Alerts nobody trusts.** Noisy alerts train people to ignore the channel, which is worse than no
   alerting because it feels like coverage.

## Assessing the collector fleet

Per host:

```bash
systemctl is-active netdata
systemctl status netdata --no-pager | head -10
curl -s http://localhost:19999/api/v1/info | jq '.version, .uptime'
```

Then check the plugins that matter for that host's role:

| Host role | Plugins that should be enabled |
|---|---|
| Database | PostgreSQL, plus the storage plugin for its filesystem |
| Storage / hypervisor | ZFS, disk, and the system plugins |
| All | CPU, memory, network, disk I/O, systemd unit state |

A database host running the collector *without* the PostgreSQL plugin is the most common partial
failure. It looks monitored on a coverage table and tells you nothing about the database.

## Assessing the aggregation layer

```bash
# Grafana
journalctl -u grafana-server | tail -50    # provisioning errors
```

Check that it is reachable, which datasources are configured and healthy, and how many dashboards
exist. Then check streaming: is there a parent collector, and are all children reporting to it?

Without a parent, diagnosis means visiting each host individually, which is exactly what nobody does
at 3am. Without centralized logs, troubleshooting is SSH and grep across the fleet.

## Deciding what to alert on

Alert on symptoms users feel, and on conditions that will *become* those symptoms with enough lead
time to act.

| Alert on | Do not alert on |
|---|---|
| Disk or pool above 85% and rising | Every CPU spike |
| Replication lag beyond the recovery objective | Momentary connection count changes |
| WAL archiver failing | Individual slow queries |
| Backup job not succeeding within its window | Metrics with no defined response |
| Service down, or health check failing | Anything nobody would act on at 3am |

The test for a new alert: *what would the recipient do about it?* If the answer is "look at it and
then do nothing", it belongs on a dashboard, not in an alert channel.

## Critical metrics by domain

| Domain | Leading indicators |
|---|---|
| PostgreSQL | Replication lag, connection utilization, WAL archive lag, dead tuple ratio, checkpoint frequency |
| ZFS | Pool capacity, CKSUM/READ/WRITE errors, scrub age, ARC hit ratio, snapshot space |
| Host | Drive wear percentage, memory pressure, swap activity, load relative to core count, systemd failed units |
| Hypervisor | Cluster quorum, node membership, per-node storage capacity, backup job success |

## Reporting rollout status

Report coverage as a fraction of the inventory, not as a count. Structure:

- Aggregation layer: reachable, datasource health, dashboard inventory
- Per-host table: collector state, version, role-relevant plugins present
- Streaming: parent host, children reporting versus expected
- Centralized logs: tool, hosts forwarding
- Gaps, as specific named hosts and specific named dashboards, not as percentages

"Coverage is at 70%" is not actionable. "These four hosts have no collector, and there is no
dashboard for replication lag" is.

## When to hand off

| Need | Skill |
|---|---|
| What the metrics mean for the database | `postgres-operations` |
| What the metrics mean for the pool | `zfs-storage` |
| Host-level thresholds | `linux-host-tuning` |
| Using monitoring during a live incident | `incident-response` |
