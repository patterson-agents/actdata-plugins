# Drafting a task (a category)

A task is a high-level, abstract container. It is a theme, not a unit of work. Issues live
underneath it.

## Use a task when

- Grouping related issues under a coherent theme
- Creating a tracking container for an ongoing area of work
- Establishing priority for a domain, since tasks carry the priority field and issues do not

## Do not use a task when

The user is describing a specific, finishable piece of work. That is an issue. See
`issue-template.md`.

The test: **could someone mark this done?** "Replace the failing drives in the storage node" can be
finished. "Infrastructure and hardware" cannot -- it is an area that will always have more work in
it. The first is an issue, the second is a task.

## Template

```text
Title:       [Domain or category name]
Description: [One or two sentences naming what falls under this category.]
Priority:    [Critical / High / Medium / Low / None]
```

## Examples

```text
Title:       Platform Engineering and Automation
Description: Infrastructure as code, server configuration management, script consolidation, and
             provisioning automation.
Priority:    High
```

```text
Title:       Reliability and Failover
Description: Failover readiness, backup restoration, database high availability, horizontal scaling,
             alerting, and routing.
Priority:    High
```

```text
Title:       Observability and Monitoring
Description: Metrics collection, dashboards, centralised logging, and alerting across all
             infrastructure.
Priority:    High
```

## Style

- Title is a noun phrase in title case.
- Description is one or two sentences listing what falls under the category. It is a scope
  statement, so someone filing a new issue can tell whether it belongs here.
- No em-dashes.
- No first or third person.

Full conventions: the `ops-reporting` skill's `references/writing-conventions.md`.

## How many categories

Enough to make the backlog navigable, few enough that placing a new issue is obvious. Roughly six to
ten works for most estates.

Two failure modes. Too few, and every issue lands in a catch-all nobody prioritises. Too many, and
issues that belong together get separated, so no category ever looks important enough to staff.

If a category has accumulated no issues over a quarter, it was probably an aspiration rather than an
area of work.

## Submitting

For one item, draft it and present it for review.

For several, append to the JSON file consumed by the creation script:

```json
{
  "type": "task",
  "title": "Category name",
  "description": "What falls under this category.",
  "priority": "High"
}
```
