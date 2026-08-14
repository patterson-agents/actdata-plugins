---
name: ci-troubleshooting
description: This skill should be used when a GitLab CI integration is not working -- "Claude isn't responding to @claude", "the job can't open an MR", "authentication errors in the pipeline", "the MCP server won't connect", "the job runs but nothing happens" -- or when diagnosing pipeline failures involving credentials, tokens, tool permissions or triggers. Covers the common failure modes and how to distinguish them.
---

# CI troubleshooting

Diagnosing a GitLab CI integration that is not behaving. Ordered by how often each cause is the real
one.

## First: is the job running at all?

Before diagnosing behaviour, confirm the job executed. A large share of "Claude isn't responding" is
a pipeline that never started.

Check CI/CD, Pipelines for a run at the expected time. If nothing is there, the problem is the
trigger, not Claude.

## Claude not responding to @claude

Work down this list in order:

1. **Was a pipeline triggered?** Manual, MR event, or webhook. If not, the trigger is the fault.
2. **Is there actually a listener?** GitLab does **not** natively run a job on a comment. The
   `@claude` workflow needs a webhook on Comments (notes) that calls the pipeline trigger API. Without
   one, mentions do nothing however correct the job is.
3. **Is it `@claude` and not `/claude`?** The mention form is `@claude`.
4. **Do the `rules:` match this trigger?** A job with only
   `if: '$CI_PIPELINE_SOURCE == "web"'` does not run on a comment-driven API trigger.
5. **Are the provider variables present** on the ref the pipeline ran against? A *protected* variable
   is absent on an unprotected branch, and the job then fails in a way that looks like a bad key.

## Job cannot write comments or open merge requests

The job runs, does work, and then cannot publish it.

| Cause | Check |
|---|---|
| Insufficient token permissions | `CI_JOB_TOKEN` may not have enough for the project. A Project Access Token with `api` scope does. |
| The tool is not allowed | `mcp__gitlab` must appear in `--allowedTools` |
| No context | Without MR context or `AI_FLOW_*` variables the job may not know what to comment on |
| Branch protection | Claude cannot push to a protected branch. That is intended; changes should flow through an MR. |

Check the allowlist first. It is the cheapest to verify and a common omission, since the job appears
entirely healthy without it.

## Authentication errors

**Claude API:** confirm `ANTHROPIC_API_KEY` is valid, unexpired, and actually present on this ref.
Masked and protected are different settings; a protected variable is unavailable on unprotected refs.

**Bedrock:** verify the OIDC configuration, that the role's trust policy admits this project and ref,
that `aud` matches the audience configured on the IAM provider, and that the region has the model you
are requesting.

**Google Cloud:** verify WIF configuration and service account impersonation. Check
`GCP_WORKLOAD_IDENTITY_PROVIDER` has **no** `//iam.googleapis.com/` prefix -- the prefix belongs in
the credential configuration's `audience` field, and including it in both is a frequent cause of an
opaque failure.

For both clouds, confirm model availability in the chosen region. Availability varies, and the error
for an unavailable model does not always say so.

## The MCP server will not connect

**In an interactive session**, the HTTP server at `/api/v4/mcp`:

1. All three GitLab settings enabled? Duo on, beta features on, MCP access allowed. On GitLab.com
   these are per top-level group.
2. Instance on 18.6 or later?
3. Has the OAuth registration rate limit been hit? Ten per hour per IP. Repeated retries exhaust it
   and then fail differently from the original problem.
4. Is `GITLAB_MCP_URL` set, and does it end in `/api/v4/mcp`?

**In a CI job**, that is a different binary: `/bin/gitlab-mcp-server` from the runner image. If it is
absent the example's `|| true` swallows the failure silently, and the job then runs without
`mcp__gitlab` tools. Symptom: the job succeeds but never comments or opens an MR.

To confirm, remove the `|| true` temporarily and let the job fail loudly.

## A tool is missing

Check the GitLab version against the tool's minimum. **Every MCP tool is version-gated**, and several
common ones arrived only in 19.3 (`list_merge_requests`, `add_branch`, `get_pipeline`,
`list_pipelines`, `list_wiki_pages`).

`semantic_code_search` additionally needs a Duo Core, Pro or Enterprise add-on.

See the `gitlab-mcp-server` skill's `references/tool-catalogue.md`.

## The job runs, succeeds, and nothing happened

Usually one of:

- `mcp__gitlab` missing from `--allowedTools`, so it had no way to publish.
- `/bin/gitlab-mcp-server` absent, failure swallowed by `|| true`.
- `AI_FLOW_INPUT` unset, so it ran the default prompt against no particular context.
- `--max-turns` too low, so it stopped mid-task.

Add `--debug` and read the job log rather than inferring. All four look identical from the pipeline
status.

## Costs more than expected

Two meters: runner minutes and API tokens.

- Is `--max-turns` set? Without it, a task that fails to converge keeps going.
- Is `timeout:` set on the job?
- Is concurrency limited? Several triggered jobs can run in parallel unnoticed.
- Is `CLAUDE.md` large? It is prepended to every run's context.

An unbounded job triggered by a comment is a cost incident waiting to happen, because anyone who can
comment can start one.

## Getting more detail

- `--debug` on the `claude` invocation for verbose output.
- `claude --help` inside the job to see what the installed CLI version supports. Flags vary by
  version, and the integration is in beta.
- GitLab maintains this integration; issues go to them. See GitLab issue #561564.
