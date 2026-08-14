# Weekly status report

For a manager. Brief, prose-first, and free of operational metadata they already have in the tracker.

---

## Structure

```markdown
## Week of [Monday date] to [Friday date]

### Highlights

[One to three sentences. What moved forward that matters.]

### Investigations

[What was looked into, and what was found. Reference item keys where useful, but do not recap what
the reader can open in the tracker.]

### Blockers

[Specific things that prevented progress. Named, dated, concrete.]

### Next week

[One to three priorities. Not every open item, just what matters.]

### Decisions needed

[Questions where the reader's input is required. Omit the section entirely if there are none.]
```

## Style

- No em-dashes.
- Prose for narrative. Bullets only for genuinely list-shaped content.
- No first or third person framing in the summary sections: "the drive replacement was scheduled",
  not "I scheduled the drive replacement".
- **First person is correct in Blockers and Decisions needed**, because those sections are direct
  asks. Depersonalising a request turns it into a statement, and statements do not get replies.

Full rules: `writing-conventions.md`.

## What to leave out

| Leave out | Why |
|---|---|
| Project and portal IDs, tracker links | The reader already has them |
| Full item descriptions | They can open the item |
| Background the reader already knows | Especially anything they wrote |
| Hour-by-hour breakdowns | Nobody is auditing your time; they are deciding what to do next |

Every omitted line makes the remaining ones more likely to be read.

## The section that earns the report

**Decisions needed** is the part that produces a response. A status report with no ask is a broadcast;
one with a clear question is a conversation, and it is how a manager finds out where they are the
bottleneck.

If a decision has been waiting more than a week, say so. A decision the reader has forgotten they owe
you looks like slow progress on your side.

## Worked example

```markdown
## Week of April 8 to April 12

### Highlights

The assessment cheatsheet now covers database performance, storage, kernel tuning and disk health
with pass/fail criteria for each. Initial triage on the primary identified a filesystem tuning gap
and roughly 8 GB of unused indexes. The metrics dashboard is up and reporting from the primary;
rollout to the rest of the fleet is in progress.

### Investigations

The filesystem tuning gap on the primary was confirmed: recordsize is at the 128K default against 8K
database pages. Remediation needs planning, since recordsize only affects new writes and the full
benefit requires recreating the dataset. Last week's query performance findings were re-validated
against current statistics, and the same three queries still dominate total execution time.

### Blockers

Backup server diagnosis is waiting on access to the host, requested Tuesday. Drive replacements were
ordered on the 3rd and have not arrived, so the resilver cannot be scheduled.

### Next week

Move the first server configuration into the infrastructure repository as a proof of concept.
Continue the metrics rollout to the remaining hosts. Begin vacuum and reindex work during off-hours.

### Decisions needed

Do we keep the existing monitoring tool or migrate fully to the new stack? Either is workable, but
running both indefinitely splits attention and neither ends up trusted.
```

Note what the example does not contain: no item IDs recapped with their full descriptions, no list of
every task touched, and no explanation of what recordsize is. The reader is told the gap was
confirmed and that remediation needs planning, which is the part they act on.
