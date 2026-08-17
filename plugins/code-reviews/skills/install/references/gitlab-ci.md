# GitLab CI

GitLab maintains its own Claude Code CI/CD integration. It is the harness; this plugin supplies the
review guidance the job's prompt points at. Nothing bespoke is needed, and in particular no script
that posts comments — the job's Claude Code process posts them itself through the GitLab MCP tools.

> [!NOTE]
> The integration is in beta and maintained by GitLab, not Anthropic. Flags vary by CLI version;
> run `claude --help` inside a job to confirm what the installed version supports.

## Install

Copy `templates/gitlab-ci-review-job.yml` into `.gitlab-ci.yml`, matching the project's existing
stage names rather than appending a foreign-looking block. If the project uses `include:` for
shared templates, ask whether the job belongs in the template project instead.

## How the job posts back

Two mechanisms exist, and which one is available depends on the runner image:

**Duo-enabled runner images** ship `/bin/gitlab-mcp-server`, a binary that supplies `mcp__gitlab`
tools inside the job; naming `mcp__gitlab` in `--allowedTools` is what lets Claude comment on the
merge request. **Standard Docker runners do not have this binary** — invoking it exits 127 — so on
a stock image (`node:24-alpine`, for example) the job posts through `glab` instead, authenticated
with a project access token:

```yaml
script:
  - |
    if [ -n "${GITLAB_ACCESS_TOKEN:-}" ]; then
      glab auth login --hostname "$CI_SERVER_HOST" --token "$GITLAB_ACCESS_TOKEN"
      POSTING="Post each finding with 'glab mr note create ...'."
    else
      POSTING="Print the review to stdout and state that nothing was posted."
    fi
    claude -p "... $POSTING ..." \
      --allowedTools "Read Grep Glob Bash(git diff:*) Bash(glab mr note:*) Bash(glab mr view:*)" \
      --max-turns 25
```

Without a token the job still reviews — the output lands in the job log with an explicit note that
nothing was posted, which keeps the failure visible instead of silent.

> [!IMPORTANT]
> Neither mechanism is the HTTP MCP server at `https://<host>/api/v4/mcp`. That one is for
> interactive sessions and authenticates over OAuth, which is unusable in CI. They are not
> interchangeable.

The tool allowlist stays read-only plus scoped posting commands: a reviewer has no reason to hold
`Edit`, `Write`, or a general `Bash`. A job that also implements changes is a different job.

## Triggering

```yaml
rules:
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

That is native and needs nothing else. Two refinements the template ships:

- **Skip drafts.** `CI_MERGE_REQUEST_DRAFT` exists only on GitLab 17.10 and later, so the template
  also matches a `Draft:` title prefix for older instances.
- **Start manual.** For a first run, `- if: '$CI_PIPELINE_SOURCE == "web"'` alone lets credentials
  and permissions be confirmed by someone who chose to run it.

> [!WARNING]
> `@claude`-on-comment is **not** native. GitLab does not run a job on a comment. It requires a
> project webhook on Comments (notes) calling the pipeline trigger API with `AI_FLOW_INPUT`,
> `AI_FLOW_CONTEXT`, and `AI_FLOW_EVENT`. That listener is separate infrastructure this plugin does
> not provide. Say so rather than leaving the user with a correct job that never fires.

## Tokens

| Token | Use |
|---|---|
| `CI_JOB_TOKEN` | The default. Scoped to the job, expires with it. |
| Project access token, `api` scope, masked as `GITLAB_ACCESS_TOKEN` | Only where the job needs permissions the job token does not carry |

Prefer `CI_JOB_TOKEN`; a project access token is a long-lived credential. If commenting fails with
the job token on your instance, that is the case for the access token.

## Provider credentials

The user creates these; never handle the values:

| Provider | Variables |
|---|---|
| Claude API | `ANTHROPIC_API_KEY`, masked, protected if the job runs only on protected refs |
| Amazon Bedrock | `AWS_ROLE_TO_ASSUME`, `AWS_REGION`, plus GitLab configured as an OIDC provider in AWS IAM and a role whose trust policy is restricted to this project and its protected refs. Set `CLAUDE_CODE_USE_BEDROCK: "1"`. |
| Google Cloud Agent Platform | `GCP_WORKLOAD_IDENTITY_PROVIDER` (without the `//iam.googleapis.com/` prefix), `GCP_SERVICE_ACCOUNT`, `GCP_PROJECT_ID`, `CLOUD_ML_REGION`. Set `CLAUDE_CODE_USE_VERTEX: "1"`. |

Both cloud providers authenticate over OIDC with nothing stored, which is the reason to prefer them
where the organization already uses that cloud.

## Cost bounds

`--max-turns` and job `timeout` are the two controls that bound a task which turns out harder than
expected, and neither has a useful default for an unattended job. Add `interruptible: true` so a new
push supersedes an in-flight review, and limit concurrency so triggered jobs cannot pile up
unnoticed.
