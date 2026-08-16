# Guidance layering

Which file holds what, which consumer reads which file, and what to do where they disagree.

## Precedence

Later layers win:

```text
skill methodology  →  REVIEW.md  →  ACT_CODE_REVIEW.md  →  CLAUDE.md / AGENTS.md
```

`CLAUDE.md` sits last not because project conventions outrank review policy, but because they are
the most specific statement of what this codebase considers correct. A `CLAUDE.md` rule is
reportable only when it is explicit and in scope for the changed file.

## What belongs where

| File | Holds | Does not hold |
|---|---|---|
| `REVIEW.md` | Review policy: severity recalibration, nit caps, skip rules, repo-specific checks, verification bar, summary shape | Build instructions, architecture notes, anything unrelated to reviewing |
| `ACT_CODE_REVIEW.md` | The ACT layer: organization-wide conventions that apply on top of whatever the repository decided | Repository-specific policy — that belongs in `REVIEW.md` |
| `CLAUDE.md` / `AGENTS.md` | How to work in this codebase: commands, conventions, invariants | Review-only instructions; those dilute every other session |

Length has a cost. A long `REVIEW.md` dilutes the rules that matter most; keep each layer to
instructions that change reviewer behavior.

## The `@` import caveat

`ACT_CODE_REVIEW.md` opens with `@REVIEW.md` so the ACT layer extends rather than replaces the
repository's own policy. Whether that import is expanded depends entirely on the consumer:

| Consumer | Reads | Expands `@` |
|---|---|---|
| This skill | Every layer, explicitly | Yes — following an `@path` means reading that file |
| `CLAUDE.md` memory system | `CLAUDE.md` | Yes |
| Anthropic managed Code Review | `REVIEW.md` and `CLAUDE.md` only | **No.** `REVIEW.md` is pasted verbatim; referenced files are not pulled in |
| Local built-in `/code-review` | `CLAUDE.md` | Does not read `REVIEW.md` at all |
| GitHub Copilot code review | `.github/instructions/*.instructions.md`, `AGENTS.md` | No |

Two consequences worth stating plainly rather than discovering later:

1. **The managed product will not see `ACT_CODE_REVIEW.md`.** For that surface the ACT layer has to
   be flattened into `REVIEW.md`. The `install` skill does this as an explicit, visible step and
   marks the result as generated.
2. **Copilot needs its own generated file.** Same flattening, into
   `.github/instructions/code-review.instructions.md`.

Anything generated carries a header naming its source and the regeneration step. A generated file
edited by hand is a file that will silently diverge.

## Conflicts

When two layers disagree, the later layer wins and no finding is emitted about the disagreement —
that is configuration, not a defect.

The exception worth surfacing: when a change makes a `CLAUDE.md` statement untrue, that is
reportable as a Nit, because the documentation is now wrong. This runs in both directions — code
that violates the docs, and code that outdates them.
