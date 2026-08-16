# 5. Ship automated MR review as an engine-agnostic contract inside act-gitlab-ci

- **Status:** Accepted
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
   MR review is a new capability that touches GitLab CI (its primary surface) but also ships a
   GitHub artifact.
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
| **A fifth plugin (`act-code-review`)** | Honest about the GitHub artifact. Rejected: it would duplicate act-gitlab-ci's CI knowledge (tokens, triggers, cost bounds), and its GitLab surface — the primary one — would depend on a sibling plugin, which `CONTRIBUTING.md` forbids referencing across plugin directories. |
| **Extend act-gitlab-ci** | Chosen. The primary surface is GitLab CI, the plugin already owns Claude-in-CI and pipeline review, and the marketplace's tri-runtime manifests already publish it to Copilot and Codex hosts. The GitHub Copilot instructions template is a recorded tension: a `.github/` artifact in a GitLab-named plugin. If the capability outgrows this home, splitting it out is a version bump, and this ADR is where that revisit starts. |
| **The agent posts its own comments (fetch toolset, GitLab MCP, or glab)** | Rejected. It hands the GitLab token to a process parsing untrusted input; the discussions API's position contract is exacting and a model gets it wrong at a steady rate; the HTTP MCP server authenticates over OAuth and is unusable in CI; and none of it is testable without live GitLab. |
| **A two-stage contract: engines produce findings JSON, a deterministic script posts** | Chosen. The rubric plus findings schema (`review-rubric.md`) is the stable center; engines (docker-agent, claude, codex, copilot, or any command) are adapters; one wrapper owns every side effect and is pinned by a fixture test suite. |
| **Claude Code as the only engine** | Rejected. It collapses the provider-agnostic requirement to one vendor, and the plugin already documents Claude-in-CI as an *actor* (`claude-code-ci-jobs`); conflating actor and reviewer in one job blurs the security boundary between a read-only process and one that commits. |

## Decision

Extend `act-gitlab-ci` (0.2.0 to 0.3.0) with an engine-agnostic review capability:

**1. One contract.** `skills/mr-review-agent/references/review-rubric.md` defines what a reviewer
reports, the severity scale, and the findings JSON schema. Every surface derives from it, and the
Copilot instructions file restates it; a rubric change is a change to all of them.

**2. Deterministic delivery.** `scripts/post-mr-review.ts` (CI) and `scripts/ai-review.sh`
(hooks, ad-hoc) run the engine, validate its output against the contract, and deliver findings.
Delivery modes: `inline` (positioned discussions plus a sticky, marker-identified summary note;
the default), `summary`, and `log` — the automatic fallback when no `GITLAB_TOKEN` exists,
because `CI_JOB_TOKEN` cannot post. Positions GitLab rejects (HTTP 400) degrade per finding to
plain notes rather than being dropped.

**3. The engine is confined.** Read-only toolsets in the shipped docker-agent config; the wrapper
strips `GITLAB_TOKEN` from the engine's environment; timeouts, `allow_failure: true`,
`interruptible: true`, diff budgets, and turn caps bound cost. The reviewer never blocks a merge.

**4. Scripts are copied into target repositories** (`.gitlab/ai-review/`) by the
`setup-mr-review` command, because CI jobs cannot resolve `${CLAUDE_PLUGIN_ROOT}`. The canonical,
tested copies stay in the plugin; re-running the command refreshes them.

**5. The docker-agent binary is version-pinned** (`DOCKER_AGENT_VERSION`) and downloaded at job
runtime — the repository tracks no binaries. Despite the name, no Docker daemon is involved; the
binary is standalone, which is what makes the "runs in a normal pipeline" requirement hold even
for the default engine.

## Consequences

**A GitHub artifact ships in a GitLab-named plugin.** `copilot-code-review.instructions.md` and
the `copilot` setup surface sit in `act-gitlab-ci` because the review contract, not the host, is
the unit of cohesion. The tension is real and recorded here; a future `act-code-review` split
would move the rubric and its restatements together.

**The token guidance now has a documented exception.** `claude-code-ci-jobs` says to prefer
`CI_JOB_TOKEN`; posting review comments is a case its permissions cannot cover, and the
`mr-review-agent` skill states when each applies. Without a project access token the capability
degrades to `log` mode rather than failing.

**Two engines are tested, two are best-effort.** The fixture suite exercises docker-agent's and
claude's output envelopes (saved transcripts; no engine is ever spawned in tests); codex and
copilot CLI flags are young and verified only at setup time, with `AI_REVIEW_ENGINE_CMD` as the
escape hatch. The suite (`scripts/tests/mr-review/`) runs with no
network and no engines, so the repository gate pins parsing, positioning, the 400 fallback, mode
downgrades, marker stickiness, and re-push resolution — not model quality.

**The rubric's restatements can drift.** The Copilot instructions file is a manual restatement of
the rubric, and nothing mechanical keeps them aligned; the skill instructs that they change
together. Drift here degrades one surface's judgment, not correctness of delivery.

**docker-agent version bumps are deliberate work.** Headless flags, event shapes, and safety
semantics move between releases; the pin, the transcript artifact, and the tolerant parser limit
the blast radius, and the reference documents what to re-check on a bump.
