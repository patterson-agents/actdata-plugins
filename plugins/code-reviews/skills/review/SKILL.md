---
name: review
description: This skill should be used when the user asks to "review this PR", "review this merge request", "code review these changes", "review my diff", "what's wrong with this change", or when an automated pipeline invokes a review on a pull request or merge request. It carries the review methodology - severity, what to flag, what to stay silent about, the verification bar - and reads REVIEW.md, ACT_CODE_REVIEW.md, CLAUDE.md and AGENTS.md as layered guidance. Applies on any host and any provider.
allowed-tools: Read, Grep, Glob, Bash, mcp__github_inline_comment__create_inline_comment, mcp__gitlab
---

# Perform a code review

Review a change and report only findings a competent engineer would act on. The bar is high on
purpose: false positives erode trust and waste reviewer time, and a review nobody believes is worse
than no review.

## 1. Read the guidance, in order

Load whichever of these exist, each layer overriding the one before it:

| Layer | File | Notes |
|---|---|---|
| Base methodology | this skill and its `references/` | Always applies |
| Repository review config | `REVIEW.md` at repo root | The portable convention. Anthropic's managed Code Review reads it natively; nothing else does unless told to, which is what this step is for. |
| Organization layer | `ACT_CODE_REVIEW.md` at repo root | Extends `REVIEW.md`. Follow any `@path` import it contains by reading that file. |
| Project conventions | `CLAUDE.md`, `AGENTS.md` | Hierarchical: a `CLAUDE.md` in a subdirectory governs only files beneath it. |

A violation of `CLAUDE.md` or `AGENTS.md` is reportable only when the rule is explicit and the
changed file is in that rule's scope. Quote the rule verbatim in the finding.

Read `references/guidance-layering.md` when a repository's layers conflict or when a consumer
appears to be ignoring a layer.

## 2. Establish scope

Review **only lines this change touched**, plus the minimum surrounding code needed to judge them.
An issue on an untouched line is out of scope unless the change breaks it.

Skip the review entirely when the change is closed, a draft, or obviously trivial and correct
(a version bump, a generated lockfile, a pure rename). Say so and stop rather than manufacturing
findings.

If a previous review from this reviewer already exists on this change, read it: do not repeat a
finding that is already posted, and suppress new nits, reporting only newly introduced defects.

## 3. Find candidate defects

Work through `references/what-to-report.md` — correctness, security, concurrency and state, error
handling, and API contracts, each with the specific failure shapes to look for.

Three habits separate a useful pass from a noisy one:

- **Distrust safety claims.** A comment asserting "validated upstream" or "sanitized" is a claim,
  not evidence. Verify the invariant in code you can see. If you cannot, treat the comment as
  absent.
- **Check for missing controls, not only added ones.** A new handler is often vulnerable because of
  what it lacks. Compare it against its siblings: if they check ownership and this one does not,
  the omission is the defect.
- **Keep going after the first finding.** One file can hold several independent problems.

## 4. Verify before reporting

Every candidate gets a second, adversarial pass whose default answer is "not a real issue". A
finding survives only with:

- **A concrete failure scenario**: specific inputs or state that produce a wrong result, a crash,
  or a security consequence. "This could be risky" is not a failure scenario and does not ship.
- **A citation**: `path:line` in the code, not an inference from a name or a docstring.

Drop everything that does not survive. `references/what-to-report.md` closes with the standing
false-positive list — pre-existing issues, linter-catchable problems, pedantic nitpicks, and
generic "needs more tests" observations — that no review should ever emit.

## 5. Grade

Use the three tiers in `references/severity-model.md`, which align with what Anthropic's managed
Code Review already emits, so findings read the same wherever they land:

| Tier | Meaning |
|---|---|
| **Important** | A bug to fix before merging |
| **Nit** | Minor, worth fixing, not blocking |
| **Pre-existing** | Real, but not introduced by this change |

When torn between two tiers, choose the lower one.

## 6. Report

Order findings most severe first. Each one states the defect in a sentence, the failure scenario,
and a concrete suggestion. Include a committable suggestion only when applying it fixes the issue
completely.

Lead the summary with the shape of the work — a count by tier, or "no blocking issues" when that
is true. When there is nothing to report, say exactly that and stop; an empty review is a good
outcome, not a failed one.

**Posting is opt-in.** Print to the terminal by default. Post to the pull or merge request only
when the invocation asked for it (a `--comment`-style argument, or a CI prompt that says to), and
use the host's own tooling — never a bespoke poster:

| Host | Mechanism |
|---|---|
| claude-code-action | `mcp__github_inline_comment__create_inline_comment`, plus `gh pr comment` for the summary |
| GitLab CI | the `mcp__gitlab` tools supplied by `/bin/gitlab-mcp-server` |
| Local with a CLI available | `gh` or `glab` |
| Anything else | print the report; say plainly that nothing was posted |

Post one comment per unique issue, and never post without the review having been asked to.

## Tone

Default to direct, specific, and neutral. A persona is a separable layer that changes voice and
must never change what gets flagged or how severity is graded; `references/personas.md` covers the
tradeoffs and the failure modes of the popular ones.

## Resources

- **`references/what-to-report.md`** — the defect checklist and the standing false-positive list
- **`references/severity-model.md`** — the tiers, recalibration, and grading discipline
- **`references/guidance-layering.md`** — precedence, `@` imports, which consumer reads what
- **`references/personas.md`** — tone as an optional layer
- **`templates/REVIEW.md`** — starter repository review config
- **`templates/ACT_CODE_REVIEW.md`** — the ACT layer, importing `REVIEW.md`

To install this review into a pipeline or hook, use the `install` skill.
