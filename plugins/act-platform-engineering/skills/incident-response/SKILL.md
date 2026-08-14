---
name: incident-response
description: This skill should be used during or after an outage -- when the user says "the database is down", "we have an incident", "production is broken", "help me run this incident", "write a postmortem", "write a runbook", "document this procedure", or mentions blameless postmortem, incident timeline, severity, root cause, action items, or failover procedure documentation. Covers running an incident, writing the postmortem afterwards, and turning procedures into runbooks.
---

# Incident Response

Running an incident, and the two documents that should come out of one.

## Mode check

Assessment and incident response are different jobs. During an incident, restoring service beats
understanding the cause. If the user is in an outage, stop assessing and start stabilising.

| Signal | Mode |
|---|---|
| "is X healthy", "review", "assess" | Assessment -- use the domain skills |
| "is down", "broken", "customers can't", "right now" | Incident -- this skill |

## Running an incident

**1. Establish impact before cause.** Who is affected, how, since when. Impact drives severity, and
severity drives who gets woken up. Diagnosing for twenty minutes before telling anyone is the most
common avoidable mistake.

**2. Stabilise before diagnosing.** Failing over, rolling back, or restarting restores service.
Understanding *why* can happen once users are working again. The exception is data integrity: if the
fix might lose or corrupt data, understand first.

**3. Change one thing at a time, and record it.** Parallel changes during an incident make the
outcome unattributable, and they make the postmortem timeline fiction. Keep a running log with
timestamps as you go -- reconstructing it afterwards from memory is unreliable, and memory is worst
about the parts that mattered.

**4. Preserve evidence before destroying it.** A restart clears the state that explains the failure.
Where it costs seconds, capture first: current connections, locks, `dmesg`, the failing unit's
recent logs, pool status.

**5. Say when you are stuck.** An hour of solo debugging during a customer-facing outage is a
decision, not a default. Escalate.

## Severity

| Level | Meaning |
|---|---|
| SEV1 | Full outage or a data integrity issue. Page immediately. |
| SEV2 | Major degradation, or a subsystem down with a workaround available. |
| SEV3 | Minor or contained impact. Handle in business hours. |

Any suspicion of data loss or corruption is SEV1 regardless of how few users notice.

## Communication

Update stakeholders on a fixed cadence rather than when there is news -- silence gets read as
"nothing is happening". Include: what is broken, who is affected, what is being done, when the next
update comes. Do not include an ETA unless it is real; a missed ETA costs more trust than no ETA.

## After the incident

Two artefacts, for different purposes.

**A postmortem** explains what happened and what will change. See
`references/postmortem-template.md`.

**A runbook** captures a procedure so the next person can execute it under pressure. See
`references/runbook-template.md`. If the incident was resolved by a sequence of steps that worked,
that sequence is a runbook draft, and it will never be easier to write than immediately afterwards.

## Blameless means systemic

The root cause is never a person. "An engineer pushed a bad config" is a description of a symptom;
the cause is that the deploy path had no validation step that would have rejected it.

This is not politeness. A postmortem that terminates at a person produces no fix, because the
correction "be more careful" has no mechanism. A postmortem that terminates at a missing control
produces a control.

## When a postmortem is warranted

Write one for: any SEV1; any incident over an hour; any resolution involving emergency action such
as failover, rollback or manual data repair; any incident that paged more than one person; any
near-miss that reveals a latent risk.

Skip it for: routine planned maintenance; minor issues with known causes that resolved quickly and
never reached users.

## When to hand off

| Need | Skill |
|---|---|
| Database diagnostics during the incident | `postgres-operations` |
| Pool degradation, capacity emergency | `zfs-storage` |
| Host-level resource exhaustion | `linux-host-tuning` |
| Node or cluster failure | `proxmox-virtualization` |
| Whether monitoring would have caught it | `observability` |
