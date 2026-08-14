# Maintaining an assessment document set

An infrastructure assessment produces more than one document, because it has more than one audience.
Trying to serve them all from one file produces a document that is simultaneously too detailed for
management and too sanitised to work from.

This describes the four-document split and the routing rules for keeping them separate.

---

## The four documents

| Document | Audience | Scope |
|---|---|---|
| **Management summary** | Leadership | Issues, recommendations, decisions. Clean. |
| **Working reference** | The engineer doing the work | Topology, people, IDs, working notes |
| **Checklist** | The engineer doing the work | Everything tracked or still to be assessed |
| **Cheatsheet** | The engineer doing the work | Commands, expected output, pass/fail criteria |

Only the first is a deliverable. The other three are working artefacts, and they are more useful for
being allowed to stay messy.

## Routing rules

When new information arrives, decide where it belongs before writing it anywhere.

**Management summary** gets: a newly identified issue with its full column set (category, scope,
priority, effort, severity, blast radius, current state, dependencies, owner, status); a status
change on an existing issue; a decision or recommendation needing visibility.

**Working reference** gets: a new host, address or topology detail; a person and their role; a
tracker ID or convention; a discovered service; working notes that are not deliverables.

**Checklist** gets: a new item to investigate or verify; a new sub-area of an existing assessment
area; an open question, marked so it can be found again.

**Cheatsheet** gets: a command worth recording; a new pass/fail criterion; a new investigation area
with its commands.

One piece of information often routes to two documents in different forms. Discovering that a host
runs an unexpected service adds a row to the working reference, and *may* add an issue to the
management summary if it carries risk. It is not the same content in both places.

## Management summary rules

This one is strict, because it is the one other people read.

- **No operational metadata the reader already has**: tracker IDs, project IDs, key-people lists,
  internal tooling notes. Those live in the working reference.
- **Issue-focused.** Every row is a tracked issue with the full column set. Prose belongs in the
  summary paragraph, not scattered between rows.
- **No raw command output.** Findings, not evidence. The evidence lives in the cheatsheet and the
  working reference.

## Scope discipline

A comment scoping down one tool or one script does not scope down the whole artefact. If someone
says "the triage script only needs to cover the primary", that constrains the script. It does not
constrain the checklist, which still tracks the full fleet.

This is the most common way an assessment quietly shrinks: a narrowing remark about one component
gets applied to everything, and the wider scope disappears without anyone deciding to drop it. When
in doubt, ask which artefact the constraint applies to.

## Keep internal reference separate from deliverables

Never collapse the working reference into the management summary. The temptation is real -- the
information is *there*, and merging looks like less maintenance.

What actually happens: the management document accumulates addresses, IDs and half-finished notes,
becomes unshareable, and stops being read. Then the summary gets rewritten from scratch anyway,
which is more work than keeping two files.

## Checklist conventions

Mark item state explicitly so a glance shows what remains:

| Marker | Meaning |
|---|---|
| `[ ]` | Not yet assessed |
| `[x]` | Assessed, no issue found |
| `[!]` | Assessed, issue found and tracked |
| `[?]` | Open question, needs follow-up |

`[?]` is the valuable one. Questions that surface mid-assessment are otherwise lost, and they are
frequently where the real findings come from.

## Cheatsheet conventions

Each entry: the command, what the output should look like, and the criteria separating a healthy
result from a problem. A command with no interpretation criteria is a note to self, not a cheatsheet
entry -- the point is that someone else can run it and know what they are looking at.

Organise by domain rather than by the order you discovered things. The reader arrives with a
question about one subsystem, not with your investigation history.
