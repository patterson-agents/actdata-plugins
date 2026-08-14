# Drafting an issue (concrete work)

An issue is a concrete, actionable unit of work: the thing an engineer picks up and finishes.

## Use an issue when

- A specific piece of work has been identified
- An assessment produced a finding worth tracking
- A bug, request or feature has a clear scope
- A conversation produced an action item

## Template

```text
Title: [Action-oriented or state-describing phrase]

Description:
[Paragraph 1: the current situation. What is the problem, or what has been observed?]

[Paragraph 2: what done looks like. What needs to happen, and what is the expected outcome?]

[Optional paragraph 3: context, dependencies, or who to work with.]
```

The two-paragraph shape is doing real work. The first paragraph makes the issue legible to someone
who was not in the conversation; the second makes it possible to tell when it is finished. An issue
with only the first is a complaint. An issue with only the second is an instruction with no
justification, and it is the first thing to be deprioritised when nobody remembers why it was filed.

## Examples

```text
Title: Failing drives in the storage node

Description:
The storage node has drives that are failing or have already failed. Replacements need to go in and
pool health needs to be verified after the resilver completes.
```

```text
Title: Filesystem tuning on the database primary

Description:
When the primary was upgraded to add storage, several significant filesystem tuning parameters were
overlooked. Recordsize, compression and kernel parameters all directly affect database performance.

Current settings need to be audited against best practice and a remediation plan developed. Some
changes only take effect on new writes, so the plan needs a migration path rather than a single
configuration change.
```

```text
Title: Automatic database failover

Description:
If the primary goes down, failover is currently manual or undefined. Automated promotion and
connection routing are needed so there is no scramble during an outage.

Ties into the broader reliability work.
```

## Style

- **No em-dashes.** Use commas or restructure.
- **No first or third person framing.** "X is needed", "Y has been overlooked" -- not "I want" or
  "we should".
- **No priority language in prose.** Priority is a field on the containing task, not an adjective.
- **Name people only where it identifies a real dependency**, and follow the local convention for
  how colleagues are referred to.

Full conventions: the `ops-reporting` skill's `references/writing-conventions.md`.

## Common pitfalls

| Instead of | Write |
|---|---|
| "I want to fix the failing drives" | "The storage node has drives that are failing or have already failed. Replacements need to go in." |
| "It's extremely manual to provision a user" | "User provisioning lacks automation. Adding a user requires significant manual effort across every host." |
| "We should set up monitoring" | "There is no centralised visibility into the infrastructure. Metrics collection, dashboards and log aggregation need to be deployed." |
| "This is a priority 1 issue" | Remove it from the prose. Set the priority field on the containing task. |

The pattern: describe the state of the world, not your feelings about it. State-describing prose
survives the author leaving; first-person prose does not.

## Submitting

For one item, draft it and present it for review.

For several, append to the JSON file consumed by the creation script:

```json
{
  "type": "issue",
  "title": "Issue title",
  "description": "First paragraph.<br><br>Second paragraph."
}
```

Descriptions are HTML. Replace blank lines between paragraphs with `<br><br>`; a literal newline does
not render.

## Cross-references

Where an issue depends on another, name it by its key in the description. Zoho does not auto-link
these, but a reader recognises the reference, and it survives being read outside the tracker.
