---
description: Add a Claude Code job to .gitlab-ci.yml, with a provider, trigger rules and cost bounds
argument-hint: "[api|bedrock|vertex]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Set up the Claude Code CI job

Add a job that runs Claude Code in GitLab CI.

## Choose the provider

From `$ARGUMENTS`, or ask. Load the `ci-auth-providers` skill for the tradeoffs.

| Provider | Use when |
|---|---|
| `api` | Getting started, no data-residency constraint. Simplest. |
| `bedrock` | AWS is the platform, or spend runs through an AWS agreement |
| `vertex` | GCP is the platform, same procurement logic |

If the organisation requires federated credentials, `api` is ruled out: it stores a long-lived key as
a CI/CD variable, while the other two authenticate over OIDC with nothing stored.

## Check what exists

Read the repository's `.gitlab-ci.yml` if there is one. Match its existing stage names and
conventions rather than appending a foreign-looking block. If the project uses `include:` for shared
templates, ask whether this job belongs in the template project instead.

## Build the job

Load the `claude-code-ci-jobs` skill and start from the matching example:

- `examples/quick-setup.yml`
- `examples/bedrock-oidc.yml`
- `examples/vertex-wif.yml`

Then adapt: stage names to match the project, and the prompt default to something sensible for this
repository.

## Always add the cost bounds

The upstream examples omit these. Add them before the job can run unattended:

```yaml
timeout: 30m
```

and `--max-turns N` on the `claude` invocation.

Without both, a task that fails to converge has nothing bounding its cost, and anyone who can trigger
the job can start one.

## Start with manual triggers only

```yaml
rules:
  - if: '$CI_PIPELINE_SOURCE == "web"'
```

Add `merge_request_event` and any comment-driven trigger **after** a manual run has confirmed
credentials, permissions and tool access work. A manual trigger cannot be invoked by anyone who can
comment, which makes it the right shape for the first run.

## Tell the user what to configure

The job needs variables set in the GitLab UI, which you cannot do. List them explicitly:

**Claude API:** `ANTHROPIC_API_KEY`, masked. Protected as well if the job runs only on protected refs.

**Bedrock:** `AWS_ROLE_TO_ASSUME`, `AWS_REGION`, plus GitLab configured as an OIDC provider in AWS
IAM and a role whose trust policy is restricted to this project and its protected refs.

**Vertex:** `GCP_WORKLOAD_IDENTITY_PROVIDER` (**without** the `//iam.googleapis.com/` prefix),
`GCP_SERVICE_ACCOUNT`, `GCP_PROJECT_ID`, `CLOUD_ML_REGION`.

## Mention-driven triggers need a listener

If the user wants `@claude` to work, say plainly that GitLab does not do this natively. It needs a
webhook on Comments (notes) that checks for `@claude` and calls the pipeline trigger API, passing
`AI_FLOW_INPUT` and `AI_FLOW_CONTEXT`.

This is separate work, and skipping the explanation is how people end up with a correct job that
never fires.

## Review before finishing

Run the checker over the result:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/check-pipeline.ts" .gitlab-ci.yml
```

A new AI job in an existing pipeline may surface pre-existing findings. Report them, and be clear
about which came from your change and which were already there.
