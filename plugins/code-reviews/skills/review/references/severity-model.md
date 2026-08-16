# Severity

## The three tiers

These match what Anthropic's managed Code Review emits, so a finding means the same thing whether
it came from the managed product, a CI job, or a local run.

| Tier | Emitted when | Author's expected response |
|---|---|---|
| **Important** | Merging this causes incorrect behavior, a security consequence, or data loss | Fix before merge |
| **Nit** | Real and worth fixing, but it will not break anything | Fix if convenient |
| **Pre-existing** | A genuine defect the change did not introduce | Note it; fix separately |

Nothing above Important exists. A "critical" tier invites inflation, and a reviewer that calls
everything critical is muted within a week.

## Grading discipline

**Grade down when torn.** Between Important and Nit, choose Nit. The cost of under-grading is that
someone fixes it next sprint; the cost of over-grading is that the next twenty findings get
skimmed.

**Severity is about consequence, not effort.** A one-character fix that corrupts billing data is
Important. A large refactor that would be tidier is a Nit at most, and usually nothing.

**Order beats labels.** Report most severe first. A reader who stops after the third finding should
have seen the three that matter.

## Recalibrating per repository

The defaults target production application code. A repository can redefine them in `REVIEW.md`, and
that redefinition wins. Common and legitimate recalibrations:

| Repository kind | Typical change |
|---|---|
| Documentation or content | Almost nothing is Important; broken links and wrong commands are the exceptions |
| Prototype or spike | Only data loss and credential exposure reach Important |
| Infrastructure as code | Blast radius raises the bar: an unscoped IAM grant or a destructive plan is Important |
| Library with external consumers | Any unversioned breaking change to the public surface is Important |

Escalation is equally valid: a repository may declare that any violation of a specific
`CLAUDE.md` rule is Important rather than a Nit.

## Volume

A review posting thirty nits is a review nobody reads. When a guidance layer caps nits, obey the
cap and report the remainder as a count in the summary. Absent a cap, use judgment: past roughly
five nits, the surplus belongs in the summary rather than inline.

On a re-review, suppress nits entirely and report only newly introduced defects. A one-line fix
should not reach round seven on style.
