<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../docs/assets/act-wordmark-white.svg">
  <img src="../../docs/assets/act-wordmark.svg" alt="ACT Data" width="260">
</picture>

# code-reviews

Automated AI code review across GitHub, GitLab, and local agents.

![skills](https://img.shields.io/badge/skills-3-00A8E1?labelColor=003767)
![agents](https://img.shields.io/badge/agents-0-003767)
![commands](https://img.shields.io/badge/commands-2-147EC2)
![scripts](https://img.shields.io/badge/scripts-2-00817D)
![deps](https://img.shields.io/badge/dependencies-none-58585B)

</div>

---

## Table of contents

- [What this is](#what-this-is)
- [What ships](#what-ships)
- [Skills](#skills)
- [Commands](#commands)
- [Install](#install)
- [How a review runs](#how-a-review-runs)
- [Configuration](#configuration)
- [Security model](#security-model)
- [What this plugin does NOT do](#what-this-plugin-does-not-do)
- [Layout](#layout)

## What this is

One review rubric and one findings contract, delivered on four surfaces:

| Surface | How | Setup |
|---|---|---|
| GitLab CI, every MR | A job runs an AI engine over the diff and posts the review | `/code-reviews:setup-mr-review gitlab-ci` |
| Git hook / scripts | `codereview.sh` reviews a local diff with whatever engine is on PATH | `/code-reviews:setup-mr-review git-hook` |
| In-session | `/code-reviews:review-mr` on any host the plugin is installed in | none |
| GitHub Copilot native review | A `.github/instructions/` file carries the rubric | `/code-reviews:setup-mr-review copilot` |

Engines are swappable (`CODEREVIEW_ENGINE`): `docker-agent` (default, provider-agnostic, a pinned
standalone binary -- no Docker daemon), `claude`, `codex`, `copilot`, or any command via
`CODEREVIEW_ENGINE_CMD`. The engine only ever produces findings; deterministic script code does
all posting.

## What ships

| Component | Count | What it is |
|---|---|---|
| Skills | 3 | The review knowledge skill plus portable adapters for both commands |
| Commands | 2 | Install a review surface; review one MR in-session |
| Scripts | 2 | The CI wrapper (`post-mr-review.ts`) and the engine-dispatch harness (`codereview.sh`), with a fixture-driven test suite |
| Templates | 4 | CI job, docker-agent config, Copilot instructions file, pre-push hook |

## Skills

| Skill | What it covers |
|---|---|
| [`mr-review-agent`](skills/mr-review-agent/) | The rubric and findings contract, engines, delivery modes, tokens, re-push semantics. Five references, four templates. |

Plus `setup-mr-review` and `review-mr` adapter skills, which make both commands reachable from
non-Claude hosts.

## Commands

| Command | Does |
|---|---|
| `/code-reviews:setup-mr-review` | Install automated review as a CI MR job, a git hook, or Copilot instructions |
| `/code-reviews:review-mr` | Review one merge request in-session against the shared rubric |

## Install

```sh
claude plugin marketplace add patterson-agents/actdata-plugins
claude plugin install code-reviews@actdata-plugins
```

## How a review runs

1. The wrapper collects the diff -- from the GitLab API in comment modes, from local git in
   tokenless mode -- and caps it with per-file and total budgets. Truncations are named in the
   summary so a partial review never poses as a full one.
2. The selected engine reviews the diff against the rubric and emits the findings contract:
   `{summary, findings: [{path, new_line, old_line, severity, title, body}]}`.
3. Delivery per `CODEREVIEW_MODE`:

| Mode | Requires | Result |
|---|---|---|
| `inline` (default) | `GITLAB_TOKEN` | A positioned discussion per finding plus a sticky summary note; positions GitLab rejects degrade to plain notes. On re-push, stale bot threads are resolved and the summary updates in place. |
| `summary` | `GITLAB_TOKEN` | The sticky summary note only. |
| `log` | nothing | Job log plus artifacts. Automatic fallback when `GITLAB_TOKEN` is unset. |

The reviewer never blocks a merge: the job runs `allow_failure: true`, and the pre-push hook is
advisory unless `CODEREVIEW_BLOCKING=1`.

## Configuration

CI/CD variables, all masked, created by the user (the plugin never handles values):

| Variable | Required | Purpose |
|---|---|---|
| Provider API key (e.g. `ANTHROPIC_API_KEY`) | yes | Whatever key the chosen engine's `model:` needs |
| `GITLAB_TOKEN` | for `inline`/`summary` | Project access token, `api` scope, Developer role. `CI_JOB_TOKEN` cannot create MR notes. |
| `CODEREVIEW_MODE`, `CODEREVIEW_ENGINE` | no | Defaults: `inline`, `docker-agent` |
| `DOCKER_AGENT_VERSION`, `DOCKER_AGENT_SHA256` | no | Pinned binary release and optional checksum |

## Security model

> [!CAUTION]
> The diff under review is untrusted input to an unattended model. The shipped docker-agent config
> is read-only (no shell, no network, no MCP); both scripts strip `GITLAB_TOKEN`,
> `GITLAB_ACCESS_TOKEN`, and `CI_JOB_TOKEN` from every engine's environment; posting is
> deterministic script code, never an agent tool call. Do not expose the GitLab token or the model
> API key to pipelines from forks.

## What this plugin does NOT do

> [!CAUTION]
> `setup-mr-review` writes to your repository (`.gitlab-ci.yml`, `.gitlab/codereview/`,
> `.github/instructions/`, hooks). `review-mr` posts to an MR only on explicit confirmation.

- **No credential handling.** Variables are set in the GitLab or GitHub UI; the plugin tells the
  user which to create and cannot create them itself.
- **The reviewer never gates a merge.** Generated findings are advice to verify, not policy.
- **Copilot native reviews are configured, not executed.** The instructions file only takes effect
  where Copilot code review is enabled on the GitHub side.
- **No webhook or mention-driven triggering.** MR-event pipelines are native GitLab behavior;
  comment-driven triggering needs a listener this plugin does not build.
- **No pipeline standards authority.** GitLab pipeline security review lives in the
  `act-gitlab-ci` plugin; neither plugin requires the other.

## Layout

```text
code-reviews/
  .claude-plugin/plugin.json
  README.md
  commands/
    setup-mr-review.md  review-mr.md
  scripts/
    post-mr-review.ts  codereview.sh
    tests/mr-review/  run-tests.sh  unit.test.ts  fixtures/
  skills/
    mr-review-agent/   SKILL.md + references/(5) + examples/(4)
    setup-mr-review/   SKILL.md (adapter)
    review-mr/         SKILL.md (adapter)
```
