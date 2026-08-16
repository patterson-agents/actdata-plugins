# 6. Ship review as skills over existing harnesses, and build no runner

- **Status:** Accepted
- **Date:** 2026-08-15
- **Supersedes:** [0005](0005-mr-review-engine-agnostic.md)

## Context

ADR 0005 shipped automated review as an engine-agnostic contract with a deterministic runner: a
TypeScript poster, a POSIX engine-dispatch harness, an eighteen-variable `CODEREVIEW_*`
environment DSL, a findings-JSON schema, sticky-marker semantics, and a fixture suite pinning all
of it — roughly 1,600 lines.

The reasoning in 0005 was sound given its premise: GitLab's discussion-position API is exacting, a
model gets it wrong at a steady rate, and putting that in deterministic code makes it testable.
What the premise missed is that **the harness was never the missing piece.** Reviewing the field
turned up a vendor-supported runner for every surface the requirement named:

| Surface | Harness that already exists |
|---|---|
| GitHub, managed | Claude GitHub App: inline comments, severity tiers, a neutral check run, `@claude review` |
| GitHub, self-hosted | `anthropics/claude-code-action` with `mcp__github_inline_comment__create_inline_comment` |
| GitLab | GitLab-maintained Claude Code CI/CD integration: `claude -p` plus `mcp__gitlab` tools from `/bin/gitlab-mcp-server` |
| Local | The built-in `/code-review` skill, with `--comment`, `--fix`, and effort levels |
| Any engine | docker-agent, `codex exec`, Copilot CLI — each accepts a prompt |

Two further findings settled it. Anthropic's own `code-review` plugin — the one this repository's
CI already runs — is **a single markdown command file with zero code**. And configuration has an
established convention: **`REVIEW.md`** at repository root, freeform markdown, injected verbatim as
the highest-priority instruction block, with documented tunables for severity, nit caps, skip
rules, repo-specific checks, verification bar, re-review convergence, and summary shape.

Against that, the 0005 design was building a second-rate copy of infrastructure that already
worked, and teaching operators a configuration language nobody else speaks.

## Options considered

| Option | Assessment |
|---|---|
| **Keep the runner, fix its defects** | The defects were real and fixable — a marker-kind collision, an argv limit, inconsistent exit codes — and all were found and fixed. Rejected anyway: a correct implementation of an unnecessary component is still unnecessary, and every fix widened the DSL operators must learn. |
| **Keep the runner as an opt-in advanced path** | Rejected. A documented escape hatch is still shipped, still maintained, still the thing a hurried operator reaches for. Retaining it preserves exactly what is being removed. |
| **Skills plus templates over existing harnesses** | Chosen. The methodology is the differentiated asset and is pure prose; the harnesses are commodity and already supported by their vendors. |
| **Invent a plugin-owned config file** | Rejected. `REVIEW.md` exists, is documented, and is read natively by the managed product. A competing file would fragment configuration for no gain. |

## Decision

Rebuild `plugins/code-reviews` as two skills and no runtime.

**1. `review` carries the methodology.** The defect checklist, the standing false-positive list,
three severity tiers matching what the managed product emits, and one verification bar: a finding
must name a concrete failure scenario — specific inputs or state producing a wrong result — and
cite `path:line` in code actually read. Candidates failing either test are dropped silently.

**2. `install` wires the review into a harness**, one reference and one template per surface, each
using that harness's native mechanism. It writes configuration and names the credentials the
operator must create; it never handles a value.

**3. Configuration layers on `REVIEW.md`.** `ACT_CODE_REVIEW.md` opens with `@REVIEW.md` and adds
the organization layer. Precedence runs methodology → `REVIEW.md` → `ACT_CODE_REVIEW.md` →
`CLAUDE.md`/`AGENTS.md`. Both are plain markdown and `@` is Claude Code's existing import syntax;
nothing new is invented.

**4. Posting always uses the host's tools** — the inline-comment MCP server under
claude-code-action, `mcp__gitlab` in GitLab CI, `gh`/`glab` locally — and only when the invocation
asked for it. Terminal output is the default.

**5. `commands/` is dropped.** Custom commands have merged into skills upstream, so the repository's
command-plus-shim pattern would duplicate every entry point for no benefit in a new plugin.

## Consequences

**Position accuracy is now the model's job, not deterministic code's.** This is the real cost of
the pivot and it should not be glossed: 0005's poster constructed `position` objects from
`diff_refs` and degraded to a plain note on rejection, which was testable offline. Now each harness
posts through its own tooling and accuracy is theirs to maintain. The tradeoff is accepted because
those vendors own the API contract, fix it faster, and already handle the failure modes — and
because unverifiable local behavior was being pinned by fixtures that only ever tested our own code.

**The test suite shrinks to what can rot.** No runtime means nothing to unit test. What remains
checks that shipped templates parse, that instruction files carry the frontmatter Copilot requires,
that every referenced resource exists, and that no runtime has crept back into the plugin.

**Guidance must be flattened for two surfaces.** The managed product reads `REVIEW.md` verbatim and
does not expand `@`; Copilot reads its own instructions file. Both receive generated, marked files,
and regeneration is a manual step an operator can forget. Divergence there is silent, which is why
the generated header names its source.

**The plugin can no longer promise identical output everywhere.** Copilot grades in its own
vocabulary; the managed product runs its own multi-agent pipeline. This plugin steers those
surfaces rather than controlling them, and the README says so rather than implying parity.

**Roughly 1,600 lines were deleted, including work completed the same day.** Recorded plainly
because the alternative — keeping it to justify having written it — is the failure mode this ADR
exists to prevent.
