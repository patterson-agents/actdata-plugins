# 5. Ship automated code review as an engine-agnostic contract in a standalone code-reviews plugin

- **Status:** Superseded by [0006](0006-review-skills-over-harness.md)
- **Date:** 2026-08-15

## Context

The repository was asked for automated code review of GitLab merge requests: an agent runs in a
CI pipeline on every submitted MR and posts feedback comparable to GitHub Copilot's or
claude-code-action's pull-request reviews, with Docker's `docker-agent` as the runner. The
requirement then widened along two axes: the review must also run **without docker-agent** (a
plain pipeline, a git hook, a normal editor session) and **beyond GitLab** (GitHub Copilot's
native code review, and Codex/Copilot hosts, which this marketplace already publishes to via
tri-runtime manifests).

Two structural questions followed:

1. **Where does it live?** ADR 0003 split the operational bundle into three plugins by topic.
   The capability was first built as an extension of `act-gitlab-ci`; once it spanned GitHub,
   GitLab, and local surfaces, that home was revisited the same day and the capability moved to
   its own plugin before anything merged.
2. **What is the unit of reuse?** A docker-agent job, a Claude Code job, a pre-push hook, and a
   Copilot instructions file cannot share code. They can share judgment.

Two facts constrain any GitLab design:

- `CI_JOB_TOKEN` cannot create notes or discussions on a merge request, so posting review
  comments requires a user-provisioned project access token.
- The diff under review is untrusted input to an unattended model; whatever runs the review is a
  prompt-injection target and must be treated as such.

## Options considered

| Option | Assessment |
|---|---|
| **Extend act-gitlab-ci** | The original build target: the primary surface is GitLab CI and the plugin owns the CI knowledge. Rejected on revisit: the capability ships GitHub artifacts (`.github/instructions/`), a host-neutral rubric, and local-agent surfaces — a `.gitlab`-named plugin carrying them misleads, and the review machinery shares no files with the pipeline tooling. |
| **A standalone `code-reviews` plugin** | Chosen. The contract is the unit of cohesion, the plugin is host-neutral by construction, and cross-plugin file references (forbidden by `CONTRIBUTING.md`) never arise because the review bundle is self-contained. |
| **The agent posts its own comments (fetch toolset, GitLab MCP, or glab)** | Rejected. It hands the GitLab token to a process parsing untrusted input; the discussions API's position contract is exacting and a model gets it wrong at a steady rate; the HTTP MCP server authenticates over OAuth and is unusable in CI; and none of it is testable without live GitLab. |
| **A two-stage contract: engines produce findings JSON, a deterministic script posts** | Chosen. The rubric plus findings schema (`review-rubric.md`) is the stable center; engines (docker-agent, claude, codex, copilot, or any command) are adapters; one wrapper owns every side effect and is pinned by a fixture test suite. |
| **Claude Code as the only engine** | Rejected. It collapses the provider-agnostic requirement to one vendor, and act-gitlab-ci already documents Claude-in-CI as an *actor*; conflating actor and reviewer in one job blurs the security boundary between a read-only process and one that commits. |

## Decision

Ship `plugins/code-reviews/` (0.1.0), an engine-agnostic review capability:

**1. One contract.** `skills/mr-review-agent/references/review-rubric.md` defines what a reviewer
reports, the severity scale, and the findings JSON schema. Every surface derives from it, and the
Copilot instructions file restates it; a rubric change is a change to all of them.

**2. Deterministic delivery.** `scripts/post-mr-review.ts` (CI) and `scripts/codereview.sh`
(hooks, ad-hoc) run the engine, validate its output against the contract, and deliver findings.
Delivery modes: `inline` (positioned discussions plus a sticky, marker-identified summary note;
the default), `summary`, and `log` — the automatic fallback when no `GITLAB_TOKEN` exists,
because `CI_JOB_TOKEN` cannot post. Positions GitLab rejects (HTTP 400) degrade per finding to
plain notes rather than being dropped.

**3. The engine is confined.** Read-only toolsets in the shipped docker-agent config; both
scripts strip every GitLab token from the engine's environment; timeouts, `allow_failure: true`,
`interruptible: true`, diff budgets, and turn caps bound cost. The reviewer never blocks a merge.

**4. Scripts are copied into target repositories** (`.codereview/`) by the
`setup-mr-review` command, because CI jobs cannot resolve `${CLAUDE_PLUGIN_ROOT}`. The canonical,
tested copies stay in the plugin; re-running the command refreshes them.

**5. The docker-agent binary is version-pinned** (`DOCKER_AGENT_VERSION`, optional
`DOCKER_AGENT_SHA256`) and downloaded at job runtime — the repository tracks no binaries. Despite
the name, no Docker daemon is involved; the binary is standalone, which is what makes the "runs
in a normal pipeline" requirement hold even for the default engine.

**6. Naming.** The plugin is `code-reviews`, by explicit request — the one departure from the
`act-*` prefix convention. The plural also avoids shadowing the upstream Anthropic `code-review`
plugin, whose `/code-review:code-review` command this repository's own GitHub workflow invokes.
The empty `plugins/code-review/` scaffold shell was removed with this change.

## Consequences

**The act-* naming convention now has one exception.** Every other plugin keeps the prefix; a
future rename to `act-code-reviews` would be a breaking change for installed consumers and should
not be done casually.

**act-gitlab-ci stays a pipeline-tooling plugin.** Its only change from this work is a
model-identifier refresh in two examples (0.2.1). Its `claude-code-ci-jobs` skill remains the
actor-in-CI integration; `code-reviews` is the reviewer. The skills state the boundary in both
directions, and neither plugin requires the other.

**The token guidance now has a documented exception.** act-gitlab-ci says to prefer
`CI_JOB_TOKEN`; posting review comments is a case its permissions cannot cover, and the
`mr-review-agent` skill states when each applies. Without a project access token the capability
degrades to `log` mode rather than failing.

**Two engines are tested, two are best-effort.** The fixture suite exercises docker-agent's and
claude's output envelopes (saved transcripts; no engine is ever spawned in tests); codex and
copilot CLI flags are young and verified only at setup time, with `CODEREVIEW_ENGINE_CMD` as the
escape hatch. The suite (`scripts/tests/mr-review/`) runs with no network and no engines, so the
repository gate pins parsing, positioning, the 400 fallback, mode downgrades, marker stickiness,
token stripping, and re-push resolution — not model quality.

**The rubric's restatements can drift.** The Copilot instructions file is a manual restatement of
the rubric, and nothing mechanical keeps them aligned; the skill instructs that they change
together. Drift here degrades one surface's judgment, not correctness of delivery.

**docker-agent version bumps are deliberate work.** Headless flags, event shapes, and safety
semantics move between releases; the pin, the transcript artifact, and the tolerant parser limit
the blast radius, and the reference documents what to re-check on a bump.
