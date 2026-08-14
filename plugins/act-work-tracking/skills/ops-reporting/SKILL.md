---
name: ops-reporting
description: This skill should be used when the user asks to "write the weekly status", "draft a status report", "update the assessment doc", "what goes in which document", "write this up for management", or asks about tone and phrasing for issues, status reports or internal engineering documents. Covers the house writing conventions, weekly status structure, and how a multi-document assessment set divides by audience.
---

# Operations Reporting

Writing engineering work up so the reader can act on it.

## The governing idea

Every document has one audience, and the audience determines what belongs in it. Most bad
engineering writing is a document trying to serve two audiences at once: a management summary
carrying internal operational detail, or a working reference that has been sanitised until it is
useless to work from.

Keep them separate. It is less work than merging them and then defending the merge.

## Reference material

| File | Covers |
|---|---|
| `references/writing-conventions.md` | The house style rules and why each exists |
| `references/weekly-status.md` | Weekly status structure, with what to leave out |
| `references/assessment-docs.md` | How a multi-document assessment set divides by audience, and routing rules |

## The rules that get broken most

**No em-dashes.** Commas, parentheses, or restructure the sentence.

**No first or third person framing in issue and status prose.** Write "X is needed" or "Y has been
overlooked", not "I want" or "we should". This is not formality for its own sake: state-describing
prose stays accurate when the author moves on, and it separates the observation from whoever made it.

First person is appropriate where the sentence genuinely is a personal ask -- a blocker you are
raising, or a decision you need. Do not strip it there; a request phrased impersonally reads as a
statement and gets no answer.

**No priority language in prose.** Priority is a field. An issue whose description argues for its own
urgency is competing with the field that already records it, and the two drift.

## Omit what the reader already has

The most common failure in a status report is recapping what the reader can see in the tracker.
Project IDs, full issue descriptions, links to items they already receive notifications about, and
background they wrote themselves are all noise. They make the report longer and less likely to be
read to the end.

Report what is not in the tracker: what moved, what did not, what is blocked, and what needs a
decision.

## Say what is blocked, specifically

"Waiting on hardware" is not a blocker; it is a category. "The drive replacements were ordered on the
3rd and have not arrived, so the resilver cannot be scheduled" is a blocker, because a reader can act
on it.

A blocker that names no person, date or dependency usually means the writer has not yet worked out
what is actually blocking them.

## When to hand off

| Need | Skill |
|---|---|
| Filing the work as a task or issue | `zoho-projects` |
| Deciding whether a finding warrants tracking | The `reporting-analyst` agent |
