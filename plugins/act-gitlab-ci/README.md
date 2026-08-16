<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../docs/assets/act-wordmark-white.svg">
  <img src="../../docs/assets/act-wordmark.svg" alt="ACT Data" width="260">
</picture>

# act-gitlab-ci

GitLab CI/CD, automated merge-request review, the GitLab MCP server, the `glab` CLI, and pipeline standards.

![skills](https://img.shields.io/badge/skills-13-00A8E1?labelColor=003767)
![agents](https://img.shields.io/badge/agents-1-003767)
![commands](https://img.shields.io/badge/commands-5-147EC2)
![mcp](https://img.shields.io/badge/mcp-gitlab-00817D)
![deps](https://img.shields.io/badge/dependencies-none-58585B)

</div>

---

## Table of contents

- [What this is](#what-this-is)
- [What ships](#what-ships)
- [Skills](#skills)
- [Commands](#commands)
- [Install](#install)
- [Configuration](#configuration)
- [Automated MR review](#automated-mr-review)
- [The pipeline checker](#the-pipeline-checker)
- [Standards provenance](#standards-provenance)
- [What this plugin does NOT do](#what-this-plugin-does-not-do)
- [Layout](#layout)

## What this is

Five related things:

1. **Automated AI review of every merge request**, engine-agnostic (docker-agent, Claude Code,
   Codex, Copilot), with the same rubric available as a git hook, an in-session command, and
   GitHub Copilot review instructions.
2. **Running Claude Code as a GitLab CI job**, across the Claude API, Amazon Bedrock and Google Cloud.
3. **The GitLab MCP server**, for interactive sessions.
4. **The `glab` CLI**, which is often the better tool for scripted GitLab work.
5. **Pipeline standards**, translated to GitLab and marked as derived throughout.

> [!IMPORTANT]
> **Two different things are called the GitLab MCP server.** The HTTP server at
> `https://<host>/api/v4/mcp` is for interactive sessions and authenticates over OAuth. The
> `/bin/gitlab-mcp-server` binary in the CI job examples is a runner-image binary supplying
> `mcp__gitlab` tools inside a job. They are not interchangeable.

## What ships

| Component | Count | What it is |
|---|---|---|
| Skills | 13 | MR review, CI jobs, auth providers, MCP server, `glab`, troubleshooting, standards, and portable command/agent adapters |
| Agents | 1 | Pipeline security review |
| Commands | 5 | Set up MR review, review an MR, set up the Claude job, review a pipeline, connect MCP |
| MCP servers | 1 | GitLab, over HTTP |
| Scripts | 3 | Zero-dependency pipeline checker, MR review wrapper, and engine-dispatch harness, with two fixture-driven test suites |

## Skills

| Skill | What it covers |
|---|---|
| [`mr-review-agent`](skills/mr-review-agent/) | Automated MR review: the rubric and findings contract, engines, delivery modes, tokens, re-push semantics. Templates for the CI job, the docker-agent config, a pre-push hook and Copilot instructions. |
| [`claude-code-ci-jobs`](skills/claude-code-ci-jobs/) | Job definition, trigger rules, `AI_FLOW_*`, CLI flags, cost bounds. Three complete job examples. |
| [`ci-auth-providers`](skills/ci-auth-providers/) | Claude API, Bedrock over OIDC, Google Cloud over WIF |
| [`gitlab-mcp-server`](skills/gitlab-mcp-server/) | Enabling, connecting, ~26 tools with version requirements, security |
| [`glab`](skills/glab/) | The GitLab CLI: issues, MRs, notes, discussions, CI, API calls |
| [`ci-troubleshooting`](skills/ci-troubleshooting/) | The failure modes, ordered by how often each is the real cause |
| [`pipeline-standards`](skills/pipeline-standards/) | Required scans, approvals, credentials, build and deploy. **Derived, not authoritative.** |

## Commands

| Command | Does |
|---|---|
| `/act-gitlab-ci:setup-mr-review` | Install automated review as a CI MR job, a git hook, or Copilot instructions |
| `/act-gitlab-ci:review-mr` | Review one merge request in-session against the shared rubric |
| `/act-gitlab-ci:setup-claude-job` | Add a Claude Code job with a provider, trigger rules and cost bounds |
| `/act-gitlab-ci:review-pipeline` | Review a pipeline, separating verified findings from what cannot be checked |
| `/act-gitlab-ci:connect-gitlab-mcp` | Connect the MCP server, checking prerequisites first |

## Install

```sh
claude plugin marketplace add patterson-agents/actdata-plugins
claude plugin install act-gitlab-ci@actdata-plugins
```

## Configuration

The plugin ships `.mcp.json` pointing at an environment variable, because the endpoint is
instance-specific and no host is hardcoded anywhere in this repository:

```sh
export GITLAB_MCP_URL="https://<your-gitlab-host>/api/v4/mcp"
```

With it unset, the server does not connect. That is intended: it fails visibly rather than reaching
somewhere unintended.

To skip the plugin's config entirely:

```sh
claude mcp add --transport http gitlab https://<your-gitlab-host>/api/v4/mcp
```

### MCP prerequisites

Three settings, all required, and they are the usual reason a correct configuration will not connect.
Each is **per top-level group on GitLab.com** but **instance-wide on Self-Managed and Dedicated**:

1. GitLab Duo set to "Always on" or "On by default"
2. Beta and experimental features enabled
3. MCP access allowed

Minimum GitLab 18.6 for beta. Free, Premium and Ultimate all qualify.

> [!NOTE]
> Every MCP tool is version-gated, 18.3 through 19.3. An 18.6 instance has substantially fewer tools
> than the catalogue lists. Check `skills/gitlab-mcp-server/references/tool-catalogue.md` before
> concluding a tool is broken.

## Automated MR review

One review rubric and findings contract, four ways to run it:

| Surface | How | Setup |
|---|---|---|
| GitLab CI, every MR | A job runs an AI engine over the diff and posts the review | `/act-gitlab-ci:setup-mr-review gitlab-ci` |
| Git hook / scripts | `ai-review.sh` reviews a local diff with whatever engine is on PATH | `/act-gitlab-ci:setup-mr-review git-hook` |
| In-session | `/act-gitlab-ci:review-mr` on any host the plugin is installed in | none |
| GitHub Copilot native review | A `.github/instructions/` file carries the rubric | `/act-gitlab-ci:setup-mr-review copilot` |

Engines are swappable (`AI_REVIEW_ENGINE`): `docker-agent` (default, provider-agnostic, a pinned
standalone binary -- no Docker daemon), `claude`, `codex`, `copilot`, or any command via
`AI_REVIEW_ENGINE_CMD`. Delivery is mode-selected (`AI_REVIEW_MODE`): `inline` posts one
positioned discussion per finding plus a sticky summary, `summary` posts the note alone, `log`
writes to the job log and artifacts.

> [!IMPORTANT]
> Posting MR comments requires a project access token (`GITLAB_TOKEN`, `api` scope, masked):
> `CI_JOB_TOKEN` cannot create notes. Without one, the job automatically falls back to `log`
> mode. The reviewer never blocks a merge (`allow_failure: true`), and the engine never sees the
> GitLab token -- the diff it reviews is untrusted input. Do not expose the token or the model
> API key to pipelines from forks.

See [`skills/mr-review-agent/`](skills/mr-review-agent/) for the rubric, mode and engine
matrices, and the security model.

## The pipeline checker

```sh
bun plugins/act-gitlab-ci/scripts/check-pipeline.ts .gitlab-ci.yml
```

Output `LEVEL|file|line|rule|message`. Exit 0 clean, 1 errors, 2 could not evaluate. No dependencies.

> [!CAUTION]
> It is a regex scanner, not a YAML parser. It cannot follow `include:` or `extends:`, cannot see
> settings configured in the GitLab UI, and cannot tell whether a scan gates the pipeline or runs
> with `allow_failure: true`. **A clean run means "nothing obvious found", never "compliant".**
>
> The standard requires shared templates, which the checker cannot follow, so false "missing scan"
> findings are expected on a well-structured pipeline.

## Standards provenance

The `pipeline-standards` skill is **translated** from a standard written for Azure DevOps and GitHub.
It has not been reviewed by that standard's owner.

> [!WARNING]
> **The source standard does not permit GitLab.** Its version-control clause reads *"Use Azure DevOps
> or GitHub. Nothing else."* GitLab's built-in scanners are not on the approved tools list either;
> the approved tools are Checkmarx, GitLeaks and Trivy. A GitLab pipeline is an exception to that
> standard rather than an implementation of it, and a compliant one disables the native scanners it
> would otherwise get for free.
>
> This conflict is recorded, not resolved. See
> [`skills/pipeline-standards/_SOURCES.md`](skills/pipeline-standards/_SOURCES.md).

Gaps marked `[TBD]` in the source stay `[TBD]`, including no named DAST tool, no artifact retention
period, no coverage threshold and no scan severity gate.

## What this plugin does NOT do

> [!CAUTION]
> `setup-claude-job` and `setup-mr-review` write to your repository (`.gitlab-ci.yml`,
> `.gitlab/ai-review/`, `.github/instructions/`, hooks). Everything else is read-only, and
> `review-mr` posts to an MR only on explicit confirmation.

- **No credential handling.** It never reads, writes or prompts for a token or model API key.
  Variables are set in the GitLab UI, which the plugin tells you to do and cannot do for you.
- **No webhook setup.** `@claude` mentions need a listener calling the pipeline trigger API. GitLab
  does not do this natively and this plugin does not build it. MR-event triggering is native and
  is what the review job uses.
- **The reviewer never gates a merge.** The review job runs with `allow_failure: true`, and the
  pre-push hook is advisory unless `AI_REVIEW_BLOCKING=1`. Generated findings are advice to
  verify, not policy.
- **Copilot native reviews are configured, not executed.** The instructions file only takes
  effect where Copilot code review is enabled on the GitHub side.
- **No authority on standards.** See above. It reports derived rules as derived.
- **No GitLab administration.** Enabling Duo, beta features and MCP access are admin or group-owner
  actions.
- **Not a compliance certificate.** The checker finds obvious problems. It does not certify anything.

## Layout

```text
act-gitlab-ci/
  .claude-plugin/plugin.json
  .mcp.json
  README.md
  agents/pipeline-security-reviewer.md
  commands/
    setup-mr-review.md  review-mr.md
    setup-claude-job.md  review-pipeline.md  connect-gitlab-mcp.md
  scripts/
    check-pipeline.ts  post-mr-review.ts  ai-review.sh
    tests/  run-tests.sh  compliant/  violating/
    tests/mr-review/  run-tests.sh  unit.test.ts  fixtures/
  skills/
    mr-review-agent/      SKILL.md + references/(5) + examples/(4)
    claude-code-ci-jobs/  SKILL.md + examples/(3 yml)
    ci-auth-providers/    SKILL.md
    gitlab-mcp-server/    SKILL.md + references/(2)
    glab/                 SKILL.md
    ci-troubleshooting/   SKILL.md
    pipeline-standards/   SKILL.md + _SOURCES.md + references/(4)
```
