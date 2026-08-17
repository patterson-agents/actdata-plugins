# GitLab CI

GitLab maintains its own Claude Code CI/CD integration, and this plugin supplies the review
guidance its prompt points at. The job here differs from the upstream quick-start in one structural
way, described under [The reviewer never posts](#the-reviewer-never-posts).

> [!NOTE]
> The integration is in beta and maintained by GitLab, not Anthropic. Flags vary by CLI version;
> run `claude --help` inside a job to confirm what the installed version supports.

## Install

Copy `templates/gitlab-ci-review-job.yml` into `.gitlab-ci.yml`, matching the project's existing
stage names rather than appending a foreign-looking block, plus its companions:

| Template | Install to |
|---|---|
| `gitlab-code-review-prompt.md` | `.gitlab/code-review-prompt.md` |
| `gitlab-code-review-schema.json` | `.gitlab/code-review-schema.json` |
| `gitlab-post-review-findings.sh` | `.gitlab/post-review-findings.sh`, `chmod +x` |
| `gitlab-mention-sweep.sh` | `.gitlab/mention-sweep.sh`, `chmod +x` (only with the mention sweep) |

The job invokes the script by path, so a missing or non-executable copy fails at the moment a
finding would have been posted. If the project uses `include:` for shared templates, ask whether
the job belongs in the template project instead.

The prompt and schema live in their own files rather than inside the job's shell so the
instructions the reviewer follows can be read and tuned in a merge request, and so
suggestion-block syntax survives without a layer of YAML and shell escaping.

## The reviewer never posts

The upstream quick-start gives the model `--permission-mode acceptEdits` with
`--allowedTools "Bash Read Edit Write mcp__gitlab"`. That fits an *implementer* that writes code
and opens merge requests. A reviewer is a different job with a different threat model: **the diff
it reads is written by whoever opened the merge request**, so any tool the model holds is a tool
that untrusted text can aim.

So the reviewer here runs with `Read Grep Glob` and no shell at all, reads the change from a
precomputed diff file, and returns findings as data validated against `code-review-schema.json`
(`--output-format json --json-schema`). The pipeline then posts them. The model has no credential,
no write tool, and no posting command.

> [!WARNING]
> A wrapper script the model is allowed to *invoke* is not a substitute, if the model can also
> **write**: it can overwrite the wrapper and then run it. Either the model has no write access at
> all, or the posting step lives outside the model's reach. This design chooses the latter and
> takes the write tool away as well.

An additional benefit is turn count. Posting from inside the model costs several turns per finding
— compose the body, build the payload, call the API — and a review of a large diff can exhaust
`--max-turns` before it finishes. Returning data costs none.

## How findings are anchored

`post-review-findings.sh` turns each finding into an inline discussion — a thread anchored in the
diff, which renders in the Changes tab, collapses with the file, and can be resolved. It needs the
merge request's `diff_refs` (`base_sha`, `head_sha`, `start_sha`), which the job fetches once.

GitLab accepts three anchors, and the script picks one from the fields the finding carries:

| Finding has | `position_type` | Result |
|---|---|---|
| `line` | `text` | A thread on that line of the new file |
| `start_line` + `line` | `text` + `line_range` | A thread spanning those lines |
| neither | `file` | A thread on the file itself |

Two details that cause a `400` if missed. **`old_path` is required alongside `new_path`**, even
when the file was not renamed. And `line_code` is the SHA-1 of the file path, then the old and new
line numbers, with `0` for a side the line does not exist on:

```sh
code=$(printf '%s' "$path" | sha1sum | cut -d' ' -f1)   # a12e1750..._0_10
```

> [!NOTE]
> The `line_range` payload the script builds marks both ends `type: "new"`, so a span is only
> valid across lines the diff **adds**. A span covering unchanged context or deleted lines needs
> `context`/`old` types and the matching old line numbers; the prompt therefore tells the reviewer
> to anchor to a single added line inside such a range instead.

A `400` otherwise nearly always means the line is not one the diff touches. The script reports the
finding into the job log rather than dropping it, and continues with the rest.

Where a fix is a single-line edit, the body ends with a **suggestion block**, which GitLab renders
with an Apply button:

````markdown
```suggestion:-0+0
for (let i = 0; i < catalog.plugins.length; i++) {
```
````

## Keeping the review quiet enough to leave on

An automated reviewer earns its place by being ignorable. The automatic pass returns **only
findings serious enough to block the merge**, posts no summary note, and says nothing at all when
a change is clean — the discussion count and pipeline status already report that it ran. The
`code-review:deep` job is the same review at every severity, one manual click from the merge
request's pipeline widget.

The most common reason teams mute a bot reviewer is a wall of general notes in the activity feed.
Anchoring findings to lines keeps them beside the code, where they behave like a colleague's
review.

Two mechanisms exist for authenticating those calls, and which one is available depends on the
runner image:

**Duo-enabled runner images** ship `/bin/gitlab-mcp-server`, a binary that supplies `mcp__gitlab`
tools inside the job; naming `mcp__gitlab` in `--allowedTools` is what lets Claude comment on the
merge request. **Standard Docker runners do not have this binary** — invoking it exits 127 — so on
a stock image (`node:24-alpine`, for example) the job posts through `glab` instead, authenticated
with a project access token:

glab reads `GITLAB_ACCESS_TOKEN` and `GITLAB_HOST` from the environment, so the job sets those as
variables and runs no login step. Without a token the job still reviews — the output lands in the
job log with an explicit note that nothing was posted, which keeps the failure visible.

The credential reaches only `post-review-findings.sh`, never the model — see
[The reviewer never posts](#the-reviewer-never-posts).

> [!IMPORTANT]
> Neither mechanism is the HTTP MCP server at `https://<host>/api/v4/mcp`. That one is for
> interactive sessions and authenticates over OAuth, which is unusable in CI. They are not
> interchangeable.

The tool allowlist is read-only: a reviewer has no reason to hold `Edit`, `Write`, a general
`Bash`, or any posting command. A job that also implements changes is a different job.

## Triggering

```yaml
rules:
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

That is native and needs nothing else. Three refinements the template ships:

- **Skip drafts.** `CI_MERGE_REQUEST_DRAFT` exists only on GitLab 17.10 and later, so the template
  also matches a `Draft:` title prefix for older instances.
- **A manual deep pass.** `code-review:deep` is the same job at `when: manual` with every severity
  reported, one click from the merge request's pipeline widget.
- **Guard on the merge request.** Both jobs exit cleanly when `CI_MERGE_REQUEST_IID` is unset. A
  pipeline started from the UI on a branch has **no** `CI_MERGE_REQUEST_*` variables, so keying a
  review mode on `$CI_PIPELINE_SOURCE == "web"` reviews an empty merge request id rather than a
  change — use a manual job in the merge request pipeline instead.

> [!WARNING]
> **Mention-driven review is not native.** GitLab does not run a job on a comment, so an
> `@mention` of the review bot does nothing on its own. Anthropic's GitLab CI/CD documentation
> says the same, and is explicit that the listener is yours: add a project webhook on Comments
> (notes) *"to your event listener (if you use one)"*, and have that listener call the pipeline
> trigger API with `AI_FLOW_INPUT` and `AI_FLOW_CONTEXT` when a comment contains the mention.
> Say so rather than leaving someone with a correct job that never fires.

### Being ready for a listener before you have one

The job reads `AI_FLOW_INPUT` when it is set, so a listener can be added later without touching
the pipeline. Until one exists the variable is unset and the block is inert.

Quote that text as a request rather than appending it to the instructions. It is written by anyone
who can comment on the project, so treating it as instructions hands the reviewer's tools to a
commenter — which is why the reviewer holds no posting command at all, and the pipeline posts on
its behalf after it exits.

Three ways to answer a mention, in increasing order of what they cost to run:

| Approach | Latency | What it needs |
|---|---|---|
| A manual deep-pass job (`code-review:deep`) | Immediate, human-initiated | Nothing; it ships in this template |
| A scheduled pipeline that sweeps open merge requests for unanswered mentions | The schedule interval | A trigger token, an `api`-scoped token, and a schedule setting `SWEEP_MENTIONS` |
| A webhook listener calling the pipeline trigger API | Seconds | A service to host, secure, and monitor |

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
