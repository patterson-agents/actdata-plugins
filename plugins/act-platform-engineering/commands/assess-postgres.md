---
description: Assess a PostgreSQL instance for performance, configuration and health, producing structured findings
argument-hint: "[host] [database]"
allowed-tools: Read, Bash, Grep, Glob
---

# Assess PostgreSQL

Produce a structured assessment of a PostgreSQL instance, with each finding backed by the command
output that produced it.

## Resolve the target

1. Take the host and database from `$ARGUMENTS` if given.
2. Otherwise read `.claude/act-platform-engineering.local.md` and match on role and the `## Databases`
   table.
3. Otherwise **ask the user**. Do not assume a hostname or database name, and do not proceed with a
   placeholder.

If the settings file is missing, say so and offer the template from the `infrastructure-inventory`
skill.

## Run the assessment

Load the `postgres-operations` skill. Work through `references/performance.md` in order:

1. Version and database size
2. Active connections and state
3. Connection utilization
4. `pg_stat_statements` top queries, by total time and by mean time
5. Sequential versus index scans
6. Table bloat
7. Unused indexes
8. Key configuration parameters
9. Lock contention

For each section, run the command (or output it for the user to run), then interpret the result
against the green/red criteria in the reference. Do not report a criterion as met without the output
that shows it.

## Prioritise what you find

Some findings outrank others regardless of the order they were discovered in:

| Finding | Why it leads |
|---|---|
| Lock contention with long blocked durations | An outage in progress, not an observation |
| Connections near `max_connections` | The next connection attempt fails |
| `idle in transaction` sessions | Causes the bloat that is usually reported as the symptom |
| Everything else | Ordinary tuning |

## Output

```markdown
## PostgreSQL assessment: [host], [date]

### Healthy
- [Item, with the evidence]

### Concerns
- [Item, with evidence and what to check next]

### Issues
- [Item, with evidence and a recommended action]
```

State explicitly if a check could not be run and why -- a missing `pg_stat_statements` extension is
itself a finding, not a gap in the assessment.

## Follow-up

- Replication findings: `/act-platform-engineering:assess-replication`
- Backup findings: `/act-platform-engineering:assess-backups`
- Filesystem-level causes: `/act-platform-engineering:assess-zfs`
- Query-level reasoning: the `dba` agent
- If an issue warrants tracking, draft it with the `act-work-tracking` plugin
