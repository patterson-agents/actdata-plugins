---
description: Install automated AI code review, as a GitLab CI MR job, a git hook, or GitHub Copilot review instructions
argument-hint: "[gitlab-ci|copilot|git-hook] [inline|summary|log] [docker-agent|claude|codex|copilot]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Set up automated code review

Install the review bundle from the `mr-review-agent` skill into the current repository, on one of
three surfaces. Load that skill first for the architecture, mode matrix, and security constraints.

## Choose the surface

From the first word of `$ARGUMENTS`, or ask:

| Surface | When |
|---|---|
| `gitlab-ci` | Review every merge request in the pipeline. The primary surface. |
| `git-hook` | Review locally before pushing; no CI, no tokens. |
| `copilot` | The repository is reviewed on GitHub by Copilot's native reviewer. |

## gitlab-ci

1. Copy from the plugin into the repository at `.gitlab/ai-review/`:
   - `${CLAUDE_PLUGIN_ROOT}/scripts/post-mr-review.ts`
   - `${CLAUDE_PLUGIN_ROOT}/scripts/ai-review.sh`
   - `${CLAUDE_PLUGIN_ROOT}/skills/mr-review-agent/references/review-rubric.md`
   - `${CLAUDE_PLUGIN_ROOT}/skills/mr-review-agent/examples/review-agent.yaml`

   The copy is deliberate: a CI job cannot resolve plugin paths. Re-running this command later
   refreshes the copies.

2. Read the repository's `.gitlab-ci.yml` if there is one and match its stage names and
   conventions. Then add the job from
   `${CLAUDE_PLUGIN_ROOT}/skills/mr-review-agent/examples/mr-review-job.yml`, adapting:
   - `AI_REVIEW_MODE` from the second argument (default `inline`).
   - `AI_REVIEW_ENGINE` from the third argument (default `docker-agent`).
   - Keep `timeout`, `allow_failure: true`, `interruptible: true`, and the draft-skip rules; they
     are cost and safety bounds, not decoration.

3. If the engine is `docker-agent`, set `model:` in `.gitlab/ai-review/review-agent.yaml` to the
   user's provider and model. Ask rather than guess the provider.

4. Tell the user which CI/CD variables to create under Settings, CI/CD, Variables. Never handle
   the values:
   - The model provider key (for example `ANTHROPIC_API_KEY`), masked.
   - `GITLAB_TOKEN` for `inline` or `summary` mode: a project access token, `api` scope,
     Developer role, masked. State plainly that without it the review lands in the job log and
     artifacts only, and that neither variable may be exposed to fork pipelines.

5. Recommend the first run: open a test MR and check the job log, the artifacts, and the posted
   review before trusting it on real work.

## git-hook

1. Copy `post-mr-review.ts`, `ai-review.sh`, `review-rubric.md`, and `review-agent.yaml` to
   `.gitlab/ai-review/` as above (the harness and hook resolve them there).
2. Install `${CLAUDE_PLUGIN_ROOT}/skills/mr-review-agent/examples/git-hook-pre-push.sh`:
   - If the repository uses a hook manager (lefthook, husky, `core.hooksPath`), add it there and
     say where.
   - Otherwise copy it to `.git/hooks/pre-push` and mark it executable. Note that `.git/hooks` is
     per-clone and not versioned, so each contributor installs it themselves.
3. State the defaults: advisory (findings print, the push proceeds), `AI_REVIEW_BLOCKING=1` gates,
   `git push --no-verify` bypasses, and the engine is auto-detected from PATH unless
   `AI_REVIEW_ENGINE` is set.

## copilot

1. Copy `${CLAUDE_PLUGIN_ROOT}/skills/mr-review-agent/examples/copilot-code-review.instructions.md`
   to `.github/instructions/code-review.instructions.md`.
2. Tell the user what the file cannot do by itself: Copilot code review must be enabled for the
   repository, the custom-instructions toggle under Settings, Copilot, Code review must be on,
   and only pull requests whose head branch contains the file are affected.

## Review before finishing

For the `gitlab-ci` surface, run the pipeline checker over the result and report which findings
came from this change:

```bash
bun "${CLAUDE_PLUGIN_ROOT}/scripts/check-pipeline.ts" .gitlab-ci.yml
```
