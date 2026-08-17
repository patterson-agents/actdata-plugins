# GitLab CI

GitLab maintains its own Claude Code CI/CD integration. It is the harness; this plugin supplies the
review guidance the job's prompt points at. Nothing bespoke is needed, and in particular no script
that posts comments — the job's Claude Code process posts them itself through the GitLab MCP tools.

> [!NOTE]
> The integration is in beta and maintained by GitLab, not Anthropic. Flags vary by CLI version;
> run `claude --help` inside a job to confirm what the installed version supports.

## Install

Copy `templates/gitlab-ci-review-job.yml` into `.gitlab-ci.yml`, matching the project's existing
stage names rather than appending a foreign-looking block, and copy
`templates/gitlab-code-review-prompt.md` to `.gitlab/code-review-prompt.md`. If the project uses
`include:` for shared templates, ask whether the job belongs in the template project instead.

The prompt lives in its own file rather than inside the job's shell so that the instructions the
reviewer follows can be read and tuned in a merge request, and so the suggestion-block syntax
survives without a layer of YAML and shell escaping.

## Keeping the review quiet enough to leave on

An automated reviewer earns its place by being ignorable. The job therefore posts **only findings
serious enough to block the merge** on the automatic pass, printing everything lesser to the job
log; a pipeline started by hand from the UI (`$CI_PIPELINE_SOURCE == "web"`) reviews at every
severity. It posts no summary note and says nothing when a change is clean — the discussion count
and the pipeline status already report that the review ran.

The single most common reason teams mute a bot reviewer is a wall of general notes in the
activity feed. Anchoring findings to lines (below) keeps them in the Changes tab, beside the code,
where they behave like a colleague's review.

## How the job posts back

Findings go up as **inline discussions** — threads anchored to a line in the diff, which render
in the Changes tab, collapse with the file, and can be resolved. That needs the merge request's
`diff_refs` (`base_sha`, `head_sha`, `start_sha`), which the job fetches once and hands to the
prompt, plus a `new_path` and a `new_line` the diff actually touches:

```sh
jq -n --rawfile body .tmp/body.md --arg path "$FILE" --argjson line "$LINE" --argjson refs "$DIFF_REFS" \
  '{body: $body, position: ($refs + {position_type: "text", new_path: $path, new_line: $line})}' \
  > .tmp/note.json
glab api "projects/$PROJECT_ID/merge_requests/$MR_IID/discussions" -X POST --input .tmp/note.json
```

A `400` from that call nearly always means `new_line` is not a line the diff adds or keeps.

Where a fix is a single-line edit, the note body ends with a GitLab **suggestion block**, which
renders as an Apply button on the thread:

````markdown
```suggestion:-0+0
for (let i = 0; i < catalog.plugins.length; i++) {
```
````

`glab mr note create` posts a plain note into the activity feed instead: use it for something that
genuinely concerns the whole change, not for per-finding output.

Two mechanisms exist for authenticating those calls, and which one is available depends on the
runner image:

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
