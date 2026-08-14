<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../docs/assets/act-wordmark-white.svg">
  <img src="../../docs/assets/act-wordmark.svg" alt="ACT Data" width="260">
</picture>

# act-gitlab-ci

GitLab CI/CD, the GitLab MCP server, the `glab` CLI, and pipeline standards.

![skills](https://img.shields.io/badge/skills-6-00A8E1?labelColor=003767)
![agents](https://img.shields.io/badge/agents-1-003767)
![commands](https://img.shields.io/badge/commands-3-147EC2)
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
- [The pipeline checker](#the-pipeline-checker)
- [Standards provenance](#standards-provenance)
- [What this plugin does NOT do](#what-this-plugin-does-not-do)
- [Layout](#layout)

## What this is

Four related things:

1. **Running Claude Code as a GitLab CI job**, across the Claude API, Amazon Bedrock and Google Cloud.
2. **The GitLab MCP server**, for interactive sessions.
3. **The `glab` CLI**, which is often the better tool for scripted GitLab work.
4. **Pipeline standards**, translated to GitLab and marked as derived throughout.

> [!IMPORTANT]
> **Two different things are called the GitLab MCP server.** The HTTP server at
> `https://<host>/api/v4/mcp` is for interactive sessions and authenticates over OAuth. The
> `/bin/gitlab-mcp-server` binary in the CI job examples is a runner-image binary supplying
> `mcp__gitlab` tools inside a job. They are not interchangeable.

## What ships

| Component | Count | What it is |
|---|---|---|
| Skills | 6 | CI jobs, auth providers, MCP server, `glab`, troubleshooting, standards |
| Agents | 1 | Pipeline security review |
| Commands | 3 | Set up the job, review a pipeline, connect MCP |
| MCP servers | 1 | GitLab, over HTTP |
| Scripts | 1 | Zero-dependency pipeline checker with 23 tests |

## Skills

| Skill | What it covers |
|---|---|
| [`claude-code-ci-jobs`](skills/claude-code-ci-jobs/) | Job definition, trigger rules, `AI_FLOW_*`, CLI flags, cost bounds. Three complete job examples. |
| [`ci-auth-providers`](skills/ci-auth-providers/) | Claude API, Bedrock over OIDC, Google Cloud over WIF |
| [`gitlab-mcp-server`](skills/gitlab-mcp-server/) | Enabling, connecting, ~26 tools with version requirements, security |
| [`glab`](skills/glab/) | The GitLab CLI: issues, MRs, notes, discussions, CI, API calls |
| [`ci-troubleshooting`](skills/ci-troubleshooting/) | The failure modes, ordered by how often each is the real cause |
| [`pipeline-standards`](skills/pipeline-standards/) | Required scans, approvals, credentials, build and deploy. **Derived, not authoritative.** |

## Commands

| Command | Does |
|---|---|
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
> `setup-claude-job` writes to your `.gitlab-ci.yml`. Everything else is read-only.

- **No credential handling.** It never reads, writes or prompts for a token. Variables are set in the
  GitLab UI, which the plugin tells you to do and cannot do for you.
- **No webhook setup.** `@claude` mentions need a listener calling the pipeline trigger API. GitLab
  does not do this natively and this plugin does not build it.
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
    setup-claude-job.md  review-pipeline.md  connect-gitlab-mcp.md
  scripts/
    check-pipeline.ts
    tests/  run-tests.sh  compliant/  violating/
  skills/
    claude-code-ci-jobs/  SKILL.md + examples/(3 yml)
    ci-auth-providers/    SKILL.md
    gitlab-mcp-server/    SKILL.md + references/(2)
    glab/                 SKILL.md
    ci-troubleshooting/   SKILL.md
    pipeline-standards/   SKILL.md + _SOURCES.md + references/(4)
```
