---
name: claude-code-ci-jobs
description: This skill should be used when the user asks to "run Claude in GitLab CI", "set up the Claude job", "add Claude to my pipeline", "make @claude work on merge requests", "trigger Claude from a comment", or mentions AI_FLOW_INPUT, AI_FLOW_CONTEXT, gitlab-mcp-server in a job, --permission-mode acceptEdits, --allowedTools, or the pipeline trigger API for AI jobs. Covers job definition, trigger rules, mention-driven workflows, CLI flags, cost controls and job-level limits.
version: 0.1.0
---

# Claude Code as a GitLab CI job

Running Claude Code inside GitLab CI so it can act on issues and merge requests, commit to a branch,
and open an MR for review.

> [!NOTE]
> This integration is in beta and is maintained by GitLab, not Anthropic. Flags and variables vary by
> version of the Claude Code CLI. Run `claude --help` inside a job to see what the installed version
> supports.

## How it fits together

1. **A trigger fires.** A manual run, a merge request event, or a webhook that sees `@claude` in a
   comment and calls the pipeline trigger API.
2. **The job collects context** from the thread and repository, and builds a prompt.
3. **Claude Code runs** in the job container, with workspace-scoped write permissions.
4. **Changes flow through a merge request**, so reviewers see the diff and approvals still apply.

The last point is the security model. Claude does not push to protected branches; it proposes changes
the normal review process gates.

## Minimum setup

1. Add `ANTHROPIC_API_KEY` as a **masked** CI/CD variable under Settings, CI/CD, Variables. Protect
   it as well if the job only runs on protected refs.
2. Add a job to `.gitlab-ci.yml`. See `examples/quick-setup.yml`.

Test it by running the job manually from CI/CD, Pipelines before wiring up any automatic trigger.

## Trigger rules

```yaml
rules:
  - if: '$CI_PIPELINE_SOURCE == "web"'
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

Start with `web` only. A manual trigger cannot surprise you, and it lets you confirm the credentials
and permissions work before the job can be invoked by anyone who can comment.

## Mention-driven triggers

GitLab does not natively run a job on a comment. The `@claude` workflow needs a listener:

1. Add a project webhook for **Comments (notes)**.
2. The listener checks whether the comment body contains `@claude`.
3. If so, it calls the pipeline trigger API, passing the context as variables.

The job receives:

| Variable | Carries |
|---|---|
| `AI_FLOW_INPUT` | The instruction, usually the comment text |
| `AI_FLOW_CONTEXT` | What it applies to |
| `AI_FLOW_EVENT` | The event that triggered it |

Give `AI_FLOW_INPUT` a default so a manual run still does something sensible:

```yaml
claude -p "${AI_FLOW_INPUT:-'Review this MR and implement the requested changes'}"
```

> [!IMPORTANT]
> The trigger is `@claude`, not `/claude`. This is the most common reason a mention appears to be
> ignored.

## CLI flags

| Flag | Purpose |
|---|---|
| `-p` | The prompt, inline |
| `--max-turns` | Caps back-and-forth iterations. Set it. |
| `--permission-mode acceptEdits` | Allows file edits without interactive approval |
| `--allowedTools "Bash Read Edit Write mcp__gitlab"` | The tool allowlist |
| `--debug` | Verbose output in the job log |

Plus GitLab's own job-level `timeout:` keyword, for example `timeout: 30m`.

`--max-turns` and `timeout` are the two controls that bound cost on a task that turns out to be
harder than expected. Neither has a useful default for an unattended job.

## Token for GitLab operations

To comment or open merge requests, the job needs GitLab API access:

- `CI_JOB_TOKEN` by default, which is scoped to the job and expires with it.
- A Project Access Token with `api` scope, stored masked as `GITLAB_ACCESS_TOKEN`, where the job
  needs more than `CI_JOB_TOKEN` allows.

Prefer `CI_JOB_TOKEN`. A Project Access Token is a long-lived credential, so reach for it only when
the job genuinely needs permissions the job token does not carry.

## Two different GitLab MCP surfaces

The job examples call `/bin/gitlab-mcp-server`, a binary in the runner image supplying the
`mcp__gitlab` tools inside the job. That is **not** the HTTP MCP server at
`https://<host>/api/v4/mcp`, which is for interactive sessions and authenticates over OAuth.

Do not point a CI job at the HTTP endpoint, and do not point `.mcp.json` at the CI binary. See the
`gitlab-mcp-server` skill.

## Cost

Two meters run at once: GitLab runner minutes, and Claude API tokens.

- Use specific instructions. A vague prompt costs more turns before it converges.
- Set `--max-turns` and `timeout` on every job.
- Limit concurrency so several triggered jobs cannot run in parallel unnoticed.
- Cache package installs in the runner where possible.

An unbounded job triggered by a comment is a cost incident waiting to happen, because anyone who can
comment can start one.

## Examples

| File | Provider |
|---|---|
| `examples/quick-setup.yml` | Claude API with a masked key |
| `examples/bedrock-oidc.yml` | Amazon Bedrock over OIDC, no static keys |
| `examples/vertex-wif.yml` | Google Cloud over Workload Identity Federation |

See the `ci-auth-providers` skill for the prerequisites behind each, and `ci-troubleshooting` when a
job does not behave.

## CLAUDE.md

Claude reads `CLAUDE.md` from the repository root during a run and follows the conventions in it.
Keep it focused: it is prepended to every job's context, so length costs tokens on every run.
