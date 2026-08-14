# Incident postmortem template

Blameless, focused on systemic causes, every action item owned and dated.

---

## Structure

````markdown
# Postmortem: [Brief incident title]

| Field | Value |
|---|---|
| Incident ID | [Tracking system ID] |
| Date | YYYY-MM-DD |
| Duration | Detection to resolution (HH:MM) |
| Severity | SEV1 / SEV2 / SEV3 |
| Author | [Name] |

## Summary

[One or two paragraphs. What happened, who was affected, for how long, how it was resolved. A
non-technical reader should understand it without the rest of the document.]

## Timeline

All times in [TIMEZONE].

- HH:MM  [Event]
- HH:MM  [Event]

Run it through detection, diagnosis, mitigation, recovery, and confirmation. Include the gaps: "HH:MM
to HH:MM, no activity, nobody had been paged" is one of the most useful lines a timeline can carry.

## Impact

- **User-facing:** [Who, how, how long]
- **Internal:** [Lost work, on-call hours, deferred projects]
- **Data:** [Any loss, corruption, or inconsistency -- state explicitly if none]

## Root cause

[Systemic. Not "an engineer pushed a bad config" but "the deploy path had no validation step that
would have rejected the misconfiguration".]

Where several factors combined, list them:

1. [Factor]
2. [Factor]

## What went well

- [Specific: detection time, communication, a control that worked]

## What went wrong

- [Specific gap: missing monitoring, a manual step, an undocumented procedure]

## Where we got lucky

[Things that could have made this far worse and did not. These expose latent risks and are usually
the highest-value section, because luck is not a control.]

## Action items

| ID | Description | Owner | Due | Status |
|---|---|---|---|---|
| 1 | [Specific corrective action] | [One person] | [Date] | Not started |

Each must be specific ("add an alert for replication lag above 30s", not "improve monitoring"),
owned by a single named person, dated with a real target, and tracked in the issue tracker with the
ID recorded here.

## Lessons learned

[What did we learn that we did not know before? What assumption turned out to be wrong?]
````

---

## Style rules

- **Blameless.** No individual is a cause. Always systemic.
- **Specific and concrete.** Timestamps for everything. "The system" did things.
- **No em-dashes.** Use commas or restructure.
- **No marketing language.** This is an internal document for learning, not a status update.

## Why blameless is a mechanism, not a courtesy

A postmortem that stops at "someone made a mistake" produces the corrective action "be more
careful", which has no mechanism and changes nothing. A postmortem that continues to "there was no
control that would have caught this" produces a control.

The second effect matters more: people who expect to be blamed report less. The incident you never
hear about is the one that recurs.

## Write one for

- Any SEV1
- Any incident lasting over an hour
- Any resolution involving emergency action: failover, rollback, manual data repair
- Any incident that paged more than one person
- Any near-miss that reveals a latent risk

## Skip it for

- Routine planned maintenance windows
- Minor issues with known causes that resolved quickly and never reached users

## Publishing

Save with a dated, descriptive filename in version control. Notify the affected stakeholders and
schedule the review within a week, while the detail is still fresh.

The review is where action items get owners. A postmortem published without one tends to produce a
table of unassigned intentions.
