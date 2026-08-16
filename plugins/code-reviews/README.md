<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../docs/assets/act-wordmark-white.svg">
  <img src="../../docs/assets/act-wordmark.svg" alt="ACT Data" width="260">
</picture>

# code-reviews

High-quality code review as skills, installable into the harness you already have.

![skills](https://img.shields.io/badge/skills-2-00A8E1?labelColor=003767)
![templates](https://img.shields.io/badge/templates-7-147EC2)
![runtime](https://img.shields.io/badge/runtime-none-003767)
![deps](https://img.shields.io/badge/dependencies-none-58585B)

</div>

---

## Table of contents

- [What this is](#what-this-is)
- [What ships](#what-ships)
- [Skills](#skills)
- [Guidance layering](#guidance-layering)
- [Harnesses](#harnesses)
- [Install](#install)
- [What this plugin does NOT do](#what-this-plugin-does-not-do)
- [Layout](#layout)

## What this is

Two things, deliberately separated:

1. **The review methodology** — what a reviewer looks for, what it stays silent about, how a
   finding earns its place, and how severity is graded. Provider-agnostic and harness-agnostic
   prose, so any agent that can read files can follow it.
2. **Installation into an existing harness** — GitHub, GitLab, or local, each using its own native
   mechanism.

The review instructions and the thing that executes them are separate concerns. This plugin owns
the first and configures the second; it is not a runner.

> [!IMPORTANT]
> There is no runtime here. No poster script, no engine dispatcher, no environment-variable
> configuration language. Every surface is driven by its own vendor-supported harness, and
> customization uses `REVIEW.md`, an existing convention, rather than a file format invented here.

## What ships

| Component | Count | What it is |
|---|---|---|
| Skills | 2 | `review` (perform one) and `install` (wire one up) |
| References | 10 | The methodology in depth, and one per harness |
| Templates | 7 | Two guidance files, three CI/hook configs, one Copilot instructions file, one docker-agent config |
| Runtime | 0 | By design |

## Skills

| Skill | Does |
|---|---|
| [`/code-reviews:review`](skills/review/) | Reviews a change against the layered guidance and reports findings; posts only when asked, through the host's own tooling |
| [`/code-reviews:install`](skills/install/) | Sets up the guidance files, then wires the review into a chosen harness |

## Guidance layering

Four layers, each overriding the one before it. All are plain markdown.

| Layer | File | Purpose |
|---|---|---|
| Base | this plugin's `review` skill | The methodology |
| Repository | `REVIEW.md` | Review policy: severity recalibration, nit caps, skip rules, repo-specific checks |
| Organization | `ACT_CODE_REVIEW.md` | The ACT layer; opens with `@REVIEW.md` so it extends rather than replaces |
| Project | `CLAUDE.md`, `AGENTS.md` | How to work in this codebase |

`REVIEW.md` is Anthropic's documented convention and is read natively by managed Code Review. The
`review` skill is what makes it portable: it reads the same file on every other surface, which
nothing else does.

> [!NOTE]
> `REVIEW.md` is pasted verbatim by the managed product, so `@` imports are not expanded there.
> Surfaces that cannot follow `@` receive a generated, clearly-marked flattened file, and `install`
> tells you the regeneration step.

## Harnesses

| Surface | Harness | Posting mechanism |
|---|---|---|
| GitHub, managed | Claude GitHub App | Native inline comments and a neutral check run |
| GitHub, self-hosted | `anthropics/claude-code-action` | `mcp__github_inline_comment__create_inline_comment` |
| GitLab | GitLab-maintained Claude Code CI/CD integration | `mcp__gitlab` tools from `/bin/gitlab-mcp-server` |
| Local | Built-in `/code-review`, or a pre-push hook | Terminal output |
| GitHub Copilot | Copilot's native reviewer | Copilot's own comments |
| Other engines | docker-agent, Codex, Copilot CLI | Terminal output |

## Install

```sh
claude plugin marketplace add patterson-agents/actdata-plugins
claude plugin install code-reviews@actdata-plugins
```

Then, in the repository to be reviewed:

```text
/code-reviews:install
```

## What this plugin does NOT do

> [!CAUTION]
> `install` writes to your repository — `REVIEW.md`, workflow and pipeline files, hooks,
> `.github/instructions/`. `review` posts to a pull or merge request only when explicitly asked.

- **It is not a harness.** It does not run agents, dispatch engines, or post comments through code
  of its own. Where no supported harness exists, the answer is to use one, not to add a runner here.
- **No credential handling.** It names the variables to create and where; it never reads or writes
  a value.
- **Reviews never gate a merge.** Findings are advice to verify. The CI templates run
  non-blocking and the pre-push hook is advisory.
- **Copilot reviews are configured, not executed.** The instructions file steers Copilot's
  reviewer; it does not control what Copilot flags or how it grades.
- **No webhook infrastructure.** GitLab does not run a job on a comment natively, and this plugin
  does not build the listener that would.
- **Not a quality guarantee.** A clean review means nothing obvious was found by one probabilistic
  pass.

## Layout

```text
code-reviews/
  .claude-plugin/plugin.json
  README.md
  skills/
    review/
      SKILL.md
      references/  what-to-report.md  severity-model.md
                   guidance-layering.md  personas.md
      templates/   REVIEW.md  ACT_CODE_REVIEW.md
    install/
      SKILL.md
      references/  github-managed.md  github-actions.md  gitlab-ci.md
                   local.md  copilot-native.md  non-claude-engines.md
      templates/   claude-code-review.yml  gitlab-ci-review-job.yml
                   pre-push  code-review.instructions.md  review-agent.yaml
  scripts/tests/templates/run-tests.sh
```
