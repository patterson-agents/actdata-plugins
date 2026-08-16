# Delivery modes, engines, and re-push semantics

## Mode matrix

`AI_REVIEW_MODE` on the CI job selects delivery. The wrapper resolves the effective mode at
runtime: any comment mode without `GITLAB_TOKEN` downgrades to `log` with a notice on stderr,
because `CI_JOB_TOKEN` cannot create MR notes or discussions.

| Mode | Token | What the author sees |
|---|---|---|
| `inline` | `GITLAB_TOKEN` | A discussion anchored to each finding's diff line, plus one summary note pinned to the MR. The closest GitLab equivalent of a GitHub Copilot or claude-code-action review. |
| `summary` | `GITLAB_TOKEN` | The summary note only: counts, a findings table with `path:line` locations, truncation notices. |
| `log` | none | The rendered report in the job log, plus artifacts. |

Artifacts are written in every mode, under `ai-review-artifacts/`:

| File | Content |
|---|---|
| `transcript.ndjson` | The engine's raw output, for debugging a bad review |
| `findings.json` | The validated findings-contract object |
| `review.md` | The rendered summary, as it would appear on the MR |

## Diff acquisition

| Mode | Source | Constraint |
|---|---|---|
| `inline`, `summary` | `GET /projects/:id/merge_requests/:iid/changes` | Also supplies `diff_refs` for positioning and the server-side draft flag |
| `log` | `git diff $CI_MERGE_REQUEST_DIFF_BASE_SHA...HEAD` | The base SHA must be reachable: set `GIT_DEPTH: "0"` on the job (the template does) or fetch it explicitly |

Diff budgets apply in both paths: `AI_REVIEW_MAX_FILE_LINES` (default 1500) per file and
`AI_REVIEW_MAX_DIFF_LINES` (default 6000) total. Files cut by either budget are named in the
summary so a partial review never masquerades as a full one.

## Engine matrix

| `AI_REVIEW_ENGINE` | Invocation | Auth | Notes |
|---|---|---|---|
| `docker-agent` | `docker-agent run --exec review-agent.yaml --json --safety restricted -` | Provider key per `model:` in the config | Default. Provider-agnostic. Standalone binary, pinned by `DOCKER_AGENT_VERSION`; no Docker daemon. |
| `claude` | `claude -p --output-format json --max-turns N --allowedTools "Read Grep Glob"` | `ANTHROPIC_API_KEY`, subscription token, or the Bedrock/Vertex setups in `ci-auth-providers` | The Docker-free pipeline path. |
| `codex` | `codex exec --json` | OpenAI credentials | Best effort: flags move between versions; check `codex exec --help`. |
| `copilot` | `copilot -p <prompt>` | GitHub Copilot auth | Best effort: same caveat. The prompt travels as one argv element, so very large diffs can exceed the OS argument limit -- lower `AI_REVIEW_MAX_DIFF_LINES` or switch to `AI_REVIEW_ENGINE_CMD` with a stdin-reading invocation. |
| any | `AI_REVIEW_ENGINE_CMD` | caller's concern | Full command via `sh -c` on both surfaces (CI wrapper and local harness); prompt on stdin; must print the findings JSON. |

The local harness auto-detects an engine when `AI_REVIEW_ENGINE` is unset: the first of
`docker-agent`, `claude`, `codex`, `copilot` found on PATH.

Safety flags for docker-agent default to `--safety restricted` (`AI_REVIEW_ENGINE_FLAGS`
overrides). If a docker-agent version denies the read-only tools under `restricted`, `--yolo` is
an acceptable fallback **only because** the config's toolsets are already read-only: the approval
flag governs prompting, the toolset governs capability.

The engine subprocess never receives `GITLAB_TOKEN`, `GITLAB_ACCESS_TOKEN`, or `CI_JOB_TOKEN` --
the wrapper and the harness both strip them, so a prompt-injected engine has no way to post.
The rest of the job environment necessarily remains reachable, the model provider key included:
that is what makes the read-only toolset and the no-network rule load-bearing rather than
decorative.

## Sticky and re-push semantics

Every body the wrapper posts embeds `<!-- act-gitlab-ci:mr-review sha=<head_sha> kind=<kind> -->`
(`kind=summary` on the sticky note, `kind=finding` on discussions and fallback notes).

- **Summary note**: found by marker and updated in place (`PUT`); created once, then stable, so
  the MR never accumulates a stack of summaries.
- **Pipeline retry** (same head SHA as the marker): the run exits before invoking the engine.
  Retries are free.
- **New push** (different head SHA): stale bot discussions -- marker present, SHA differs, still
  unresolved -- are resolved, fresh discussions are posted against the new diff, and the summary
  updates. Resolved threads stay visible but collapsed, preserving the audit trail. Human threads
  are never touched: no marker, no action.
- **Draft MRs**: skipped by the job rules (`CI_MERGE_REQUEST_DRAFT` on GitLab 17.10+, a
  `Draft:` title regex elsewhere) and, belt-and-braces, by the wrapper via the API's draft flag
  in token modes. In `log` mode the wrapper never calls the API, so the job rules are the only
  draft guard.

## Failure behavior

| Failure | Result |
|---|---|
| Engine output has no valid findings object | Exit 1; transcript saved to artifacts; `allow_failure: true` keeps the MR mergeable |
| A finding's position is rejected (HTTP 400) | That finding posts as a plain note prefixed `path:line`; the rest post normally. Expected for context lines and renames, not an error. |
| Other GitLab API errors | Exit 1 with the status code; nothing is silently dropped |
| Empty diff | Exit 0, "nothing to review" |
