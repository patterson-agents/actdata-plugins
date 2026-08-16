---
name: mr-review-agent
description: This skill should be used when the user asks to "review merge requests automatically", "set up AI code review", "run a review agent in the pipeline", "post review comments on MRs", "review every MR", or mentions docker-agent, AI_REVIEW_MODE, AI_REVIEW_ENGINE, GITLAB_TOKEN for review comments, post-mr-review.ts, ai-review.sh, review-agent.yaml, review-rubric.md, a pre-push AI review hook, inline MR discussions from CI, or Copilot code review instructions. Covers the review contract, the engine matrix, delivery modes, tokens, and re-push semantics.
---

# Automated merge-request review

An engine-agnostic code review that runs on every submitted merge request, plus the same review as
a git hook, an in-session command, or GitHub Copilot's native reviewer.

## The contract, not the engine, is the product

Everything is built around two stable artifacts in this skill's `references/` and shipped alongside
the scripts:

- **`references/review-rubric.md`** -- what a reviewer looks for, the severity scale, and the
  findings JSON contract `{summary, findings: [{path, new_line, old_line, severity, title, body}]}`.
- **Deterministic delivery scripts** -- `scripts/post-mr-review.ts` (CI, posts to GitLab) and
  `scripts/ai-review.sh` (local, prints a report). The engine only ever produces findings; the
  scripts do everything with side effects.

Engines are swappable via `AI_REVIEW_ENGINE`:

| Engine | Runs | Status |
|---|---|---|
| `docker-agent` (default) | Pinned standalone binary; provider-agnostic `model:` in `review-agent.yaml`. No Docker daemon involved. | Tested pair |
| `claude` | `claude -p` headless with read-only tools; Bedrock/Vertex auth is covered by the act-gitlab-ci plugin | Tested pair |
| `codex` | `codex exec` | Best effort; verify flags per version |
| `copilot` | Copilot CLI | Best effort; verify flags per version |

Any other engine: set `AI_REVIEW_ENGINE_CMD` to a command that reads the prompt on stdin and
prints the findings JSON.

## Four surfaces

| Surface | Entry point | Setup |
|---|---|---|
| GitLab CI on every MR | `examples/mr-review-job.yml` running `post-mr-review.ts` | `/code-reviews:setup-mr-review gitlab-ci` |
| Git hooks / scripts | `scripts/ai-review.sh`, `examples/git-hook-pre-push.sh` | `/code-reviews:setup-mr-review git-hook` |
| In-session, any host | the `review-mr` command | installed with the plugin |
| GitHub Copilot native review | `examples/copilot-code-review.instructions.md` | `/code-reviews:setup-mr-review copilot` |

The CI scripts are **copied into the target repository** (conventionally `.gitlab/ai-review/`)
because a CI job cannot resolve plugin paths. Re-run the setup command to pick up plugin updates.

## Delivery modes (GitLab CI)

`AI_REVIEW_MODE` selects how findings reach the MR; see `references/review-modes.md` for detail.

| Mode | Needs | Result |
|---|---|---|
| `inline` (default) | `GITLAB_TOKEN` | One positioned discussion per finding plus a sticky summary note. Positions GitLab rejects degrade to plain notes. On re-push, stale bot threads are resolved and the summary updates in place. |
| `summary` | `GITLAB_TOKEN` | The sticky summary note only. |
| `log` | nothing | Job log plus `ai-review-artifacts/`. Automatic fallback when `GITLAB_TOKEN` is unset. |

## Tokens: when CI_JOB_TOKEN is not enough

`CI_JOB_TOKEN` cannot create notes or discussions on a merge request, which is exactly what
`inline` and `summary` modes do. Those modes need `GITLAB_TOKEN`: a project access token with
`api` scope and Developer role, stored masked.

This is the documented exception to the act-gitlab-ci plugin's guidance (in its
`claude-code-ci-jobs` skill) to prefer `CI_JOB_TOKEN`. That guidance stands wherever the job
token's permissions suffice (cloning, package registries, trigger tokens); posting review
comments is a case where they do not. Without a project access token, run `log` mode -- it needs
no token at all.

> [!CAUTION]
> The diff under review is untrusted input to the model. Keep engine toolsets read-only (the
> shipped `review-agent.yaml` already is), never hand the engine `GITLAB_TOKEN` (the wrapper
> strips it from the engine's environment), and never expose the model API key or `GITLAB_TOKEN`
> to pipelines from forks.

## Cost and blast bounds

The CI job carries `timeout: 15m`, `interruptible: true`, and `allow_failure: true`, so the
reviewer never blocks a merge and a new push supersedes the in-flight run. The wrapper adds diff
budgets on every surface (`AI_REVIEW_MAX_FILE_LINES`, `AI_REVIEW_MAX_DIFF_LINES` -- truncations
are listed in the summary), a turn cap where the engine supports one (`AI_REVIEW_MAX_TURNS`, on
the `claude` engine), and, in token modes, a no-op guard: a pipeline retry on an already-reviewed
head SHA exits before the engine runs.

## Boundary with the act-gitlab-ci plugin

The act-gitlab-ci plugin's `claude-code-ci-jobs` skill runs Claude Code in CI as an **actor**: it
edits files, commits, and opens MRs from instructions. This skill runs an engine as a
**reviewer**: read-only, structured findings, deterministic posting. Neither replaces the other; a
repository can carry both jobs, and neither plugin requires the other.

## Additional resources

### Reference files

- **`references/review-rubric.md`** -- the reviewer instruction, severity scale, findings contract
- **`references/review-modes.md`** -- mode and engine matrices, tokenless constraints, re-push semantics
- **`references/docker-agent-config.md`** -- config anatomy, toolsets, safety flags, provider swap
- **`references/gitlab-discussions-api.md`** -- position objects, diff_refs, the 400 fallback, marker dedup
- **`references/copilot-code-review.md`** -- how Copilot native review consumes instruction files

### Examples

- **`examples/mr-review-job.yml`** -- the CI job template
- **`examples/review-agent.yaml`** -- the docker-agent config template
- **`examples/copilot-code-review.instructions.md`** -- the Copilot instructions file
- **`examples/git-hook-pre-push.sh`** -- a pre-push hook wiring `ai-review.sh`
