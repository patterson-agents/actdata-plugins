---
description: Draft a weekly status report from the week's work, tracker activity and open blockers
argument-hint: "[week ending date]"
allowed-tools: Read, Bash, Grep, Glob
---

# Weekly status

Draft the week's status report for a manager.

## Gather

1. **Tracker activity.** Items created, moved or closed this week. Use the configured Zoho MCP tools
   or the projects API, with the project IDs from `.claude/act-work-tracking.local.md`.
2. **Work not in the tracker.** Investigations, assessments, documents written, conversations that
   changed direction. This is usually the most valuable content, because it is the part the reader
   cannot see anywhere else.
3. **Open blockers**, with what each is waiting on.
4. **Decisions outstanding**, including any raised in previous weeks and still unanswered.

Ask the user for anything you cannot determine. Do not infer that a closed item means the work went
smoothly.

## Structure

Load the `ops-reporting` skill and follow `references/weekly-status.md`.

```markdown
## Week of [Monday date] to [Friday date]

### Highlights
### Investigations
### Blockers
### Next week
### Decisions needed
```

Omit **Decisions needed** entirely if there are none. Do not include an empty section.

## What to cut

| Cut | Because |
|---|---|
| Project and portal IDs, tracker links | The reader already has them |
| Full item descriptions | They can open the item |
| Background the reader knows | Especially anything they wrote |
| Hour-by-hour breakdowns | They are deciding what to do next, not auditing your time |
| Every item touched | Pick what matters; a complete list reads as a complete list |

Every line cut makes the remaining ones more likely to be read to the end.

## Style

- No em-dashes.
- Prose for narrative; bullets only for genuinely list-shaped content.
- No first or third person framing in Highlights and Investigations: "the drive replacement was
  scheduled", not "I scheduled the drive replacement".
- **First person is correct in Blockers and Decisions needed.** Those sections are direct asks, and
  depersonalising a request turns it into a statement that gets no reply.

## Make the blockers actionable

"Waiting on hardware" is a category, not a blocker. Name the person, the date, or the dependency:
"drive replacements were ordered on the 3rd and have not arrived, so the resilver cannot be
scheduled".

If a decision has been outstanding more than a week, say how long. A decision the reader has
forgotten they owe you otherwise reads as slow progress on your side.

## Output

Present the draft for review. Flag anything you inferred rather than confirmed, so the user can
correct it before it goes out.
