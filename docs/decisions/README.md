# Architecture decision records

Decisions that shaped this repository, with the reasoning that produced them and the options that
were rejected.

An ADR is written when a choice is **hard to reverse, non-obvious, or likely to be questioned later**.
Most changes need no ADR. A change that a future reader would otherwise want to undo, without knowing
what it cost to arrive at, needs one.

## Index

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-fork-plugin-dev.md) | Fork `plugin-dev` rather than depend on it | Accepted |
| [0002](0002-config-driven-plugins.md) | Ship no environment identifiers; read them from a site-local settings file | Accepted |
| [0003](0003-three-plugin-split.md) | Split the operational bundle into three plugins | Accepted |
| [0004](0004-derived-pipeline-standards.md) | Ship pipeline standards as explicitly derived, and record the platform conflict | Accepted |

## Format

Numbered sequentially, filename `NNNN-kebab-case-summary.md`, never renumbered.

```markdown
# N. Decision, as a sentence in the imperative

- **Status:** Proposed | Accepted | Superseded by [NNNN](NNNN-....md)
- **Date:** YYYY-MM-DD

## Context

What situation forced a decision. State the constraints that were real at the time,
including the ones that later turn out to have been wrong.

## Options considered

| Option | Assessment |
|---|---|
| **The one you rejected** | Why. Be specific and fair to it. |
| **The one you chose** | Chosen. |

## Decision

What was decided, stated plainly enough to act on.

## Consequences

What this costs, what obligation it creates, and what a future reader needs to know
before undoing it. Include the consequences you are not happy about.
```

## Conventions

**Status is never edited away.** A decision that stops being true is marked superseded, with a link
forward. Deleting it removes the reasoning someone will need when they consider the same option
again.

**Rejected options earn real assessments.** "Rejected: too slow" teaches nothing. The next person
will reconsider that option, and the record exists so they can start from where you finished.

**Consequences include the unwelcome ones.** ADR 0001 records that forking `plugin-dev` creates a
manual re-sync obligation. ADR 0004 records that it reintroduces a lineage this repository had
deliberately removed. Those are the entries that make the record trustworthy.

**`[TBD:]` where a source is silent.** Do not resolve a gap by inference; mark it, so it can be
escalated to whoever owns the answer.

```sh
grep -rn '\[TBD' docs/ plugins/
```
