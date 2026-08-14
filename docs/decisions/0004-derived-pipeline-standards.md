# 4. Ship pipeline standards as explicitly derived, and record the platform conflict

- **Status:** Accepted
- **Date:** 2026-08-14

## Context

`act-gitlab-ci` was asked to carry ACT pipeline standards alongside its docs-sourced content.

No ACT GitLab CI conventions exist. The repository's own `CLAUDE.md` records this as a known gap:
*"No ACT GitLab CI conventions were available to base a pipeline on."*

What does exist is the **Patterson CI/CD Pipeline Standards**, implemented as
`patterson-engineering:cicd-pipeline-standards` in a sibling checkout. It is detailed and
well-sourced: seven required CI scans with named tools, a two-approver minimum with five required
checks, federated-credentials-only, build-once-and-promote, three permitted deployment strategies.

It was written for Azure DevOps and GitHub.

Translating it to GitLab surfaced a direct contradiction:

> Its version-control clause reads: *"Use **Azure DevOps or GitHub**. Nothing else."*

GitLab is not on the allowlist. Worse, the approved-software list that the standard depends on
excludes GitLab's built-in scanners — SAST, Dependency Scanning, Secret Detection and Container
Scanning are all unlisted, while Checkmarx, GitLeaks and Trivy are named. Under the standard's own
decision rule, an unlisted tool requires review.

So a GitLab pipeline aiming at compliance must **disable the scanners the platform gives it for free**
and integrate three external tools instead. That is a substantial, non-obvious cost, and it is
invisible until someone compares the tool list against the platform defaults.

## Options considered

| Option | Assessment |
|---|---|
| **Drop the standards; ship only docs-sourced content** | Cleanest. Rejected: it was explicitly requested, and a GitLab plugin with no standards leaves the question unanswered rather than answered carefully. |
| **Translate silently and present as ACT standards** | Rejected outright. It would give derived rules the authority of policy, and a reader could not tell which clauses were reviewed and which were inferred. |
| **Translate, and mark every clause derived; record the conflict** | Chosen. |
| **Translate and resolve the conflict by adding GitLab to the allowlist** | Rejected. Not this repository's decision to make. Amending another team's standard by writing a different version of it is how two conflicting standards come to exist. |

## Decision

Ship `act-gitlab-ci/skills/pipeline-standards/`, translated to GitLab, with three constraints:

**1. Provenance is stated at the top of the skill**, in a `[!CAUTION]` block, before any rule.

**2. `_SOURCES.md` records the full lineage:** the source article and its owner, the implementing
skill, a per-clause translation table with a confidence rating, and the GitLab conflict in full.

**3. The source's own meta-rules are carried over verbatim:**

> Do not add requirements that are not in this file or in `references/`. If the standard does not
> cover something, say so and mark it `[TBD]`.

> Validator scripts under `scripts/` must only enforce rules that are quoted in `references/`. A rule
> with no citation is a bug.

Every `[TBD]` in the source stays `[TBD]`. Seven survive, including that no DAST tool is named
anywhere in the standard.

The skill's trigger phrases are GitLab-qualified so they do not collide with the authoritative skill
in the same workspace, and it names that skill as the alternative:

```text
For the authoritative Azure DevOps and GitHub standard, use
patterson-engineering:cicd-pipeline-standards instead.
```

## Consequences

**The conflict is escalated, not resolved.** Whether ACT may use GitLab at all, and whether GitLab's
native scanners can be approved, are decisions for the standard's owner. The plugin's job is to make
the question visible to whoever hits it, with enough context to escalate.

**Patterson lineage returns to a repository that removed it.** This repository's governance documents
were deliberately rewritten without patterson-corp references. This skill reintroduces that lineage,
confined to one directory and labelled throughout. The alternative — encoding the rules without
naming their source — would be worse, presenting derived rules as though they originated here.

**A validator was built to the same standard as the prose.**
`act-gitlab-ci/scripts/check-pipeline.ts` enforces only rules quoted in `references/`, and each rule
in the source cites the reference documenting it. Its limitations are documented rather than hidden:
it is a regex scanner, cannot follow `include:` or `extends:`, cannot see UI-configured settings, and
cannot tell a gating scan from one with `allow_failure: true`.

Because the standard *requires* shared templates, and the checker cannot follow them, false
"missing scan" findings are expected on a well-structured pipeline. That is stated in the skill, the
review command and the agent.

**The test suite pins the blind spots.** `run-tests.sh` asserts the checker does **not** detect
things behind an `include:`. If that starts passing, the documented caveats have become wrong and
someone must update the prose. A limitation nobody notices being fixed is a documentation defect.

**A clean run is never a compliance statement.** Repeated in the skill, the command, the agent and the
script's own header:

> Treat a clean run as "nothing obvious found", not as "compliant".
