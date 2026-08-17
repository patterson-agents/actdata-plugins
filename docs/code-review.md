# Automated code review

One set of review guidelines drives every surface that reviews code here: merge requests on
GitLab, pull requests on GitHub, and GitHub Copilot. This document is how the pieces fit; the
plugin's own `install` skill has the per-surface installation detail.

## Table of contents

- [The one source of guidance](#the-one-source-of-guidance)
- [What runs where](#what-runs-where)
- [How a GitLab review works](#how-a-gitlab-review-works)
- [Answering an @mention](#answering-an-mention)
- [Keeping it quiet enough to leave on](#keeping-it-quiet-enough-to-leave-on)
- [Security model](#security-model)
- [Cost and latency](#cost-and-latency)
- [Operating it](#operating-it)

## The one source of guidance

```
skill methodology  (plugins/code-reviews/skills/review/)
        ↓
REVIEW.md          repository policy: what Important means here, what never to report
        ↓
ACT_CODE_REVIEW.md organization layer: supply chain, durable work, commit conventions
        ↓
CLAUDE.md          general project context
```

`ACT_CODE_REVIEW.md` opens with `@REVIEW.md`, so a reader that expands imports gets both. Two
surfaces do not expand imports, and each has a generated flattening instead:

| Surface | Reads | Generated from |
|---|---|---|
| `code-reviews:review` skill | every layer | — |
| GitLab CI, GitHub Actions | every layer, via the skill | — |
| Anthropic's managed Code Review | `REVIEW.md` alone | the marked ACT section inside `REVIEW.md` |
| GitHub Copilot | `.github/instructions/code-review.instructions.md` | `REVIEW.md` + `ACT_CODE_REVIEW.md` |

When you change `REVIEW.md` or `ACT_CODE_REVIEW.md`, regenerate the two flattened copies rather
than editing them; each carries a header saying so. Nothing mechanical enforces this yet, which is
the known soft spot in the design.

## What runs where

| Surface | Trigger | Posts as |
|---|---|---|
| `code-review` (GitLab) | every non-draft merge request | inline threads on the diff |
| `code-review:deep` (GitLab) | one manual click, in the merge request's pipeline | inline threads, every severity |
| `mention-sweep` (GitLab) | schedule, every few minutes | triggers a review where a mention is unanswered |
| `claude-code-review.yml` (GitHub) | every pull request | inline review comments |
| Copilot | GitHub's own reviewer | its native review |

## How a GitLab review works

```
merge request  ─▶  code-review job
                     ├── reads REVIEW.md, ACT_CODE_REVIEW.md, and the diff   (read-only tools)
                     ├── returns findings as JSON validated by a schema
                     └── post-review-findings.sh  ─▶  inline discussions
```

The reviewer and the poster are separate on purpose — see [Security model](#security-model).

Each finding becomes a thread anchored where the problem is. GitLab accepts three anchors and the
poster picks from the fields a finding carries:

| Finding carries | Anchor |
|---|---|
| `line` | that line of the new file |
| `start_line` + `line` | the span, via `line_range` |
| neither | the file itself |

Where a fix is one line, the body ends with a `suggestion` block, which GitLab renders with an
Apply button.

## Answering an @mention

GitLab runs no pipeline when someone comments, and Anthropic's GitLab integration is explicit that
mention-driven triggering needs an event listener **you** host. This repository takes the option
that needs no service: `mention-sweep` runs on a schedule, asks which open merge requests have a
mention of the review bot that the bot has not answered, and triggers a review for each through
the pipeline trigger API, passing the comment along as `AI_FLOW_INPUT`.

- **Latency is the schedule interval.** That is the honest cost of having nothing to operate.
<<<<<<< HEAD
- **A mention counts as answered** once the bot posts anything after it, so a sweep acts on a
  mention once and acts again on the next one.
=======
- **A mention is marked with an emoji award on the comment itself**, the moment a review is
  triggered. "Has the bot replied since?" is the obvious test and the wrong one: a clean review
  posts nothing by design, so the mention would stay unanswered and every sweep would pay for the
  same review again. The award also reads as an acknowledgement in the UI rather than as another
  comment.
>>>>>>> fix/gitlab-review-glab
- **The comment is quoted as a request**, not appended as instructions: anyone who can comment can
  write it, so it cannot override the posting rules or the tool scope.

If seconds matter more than simplicity, the same job accepts `REVIEW_MR_IID` and `AI_FLOW_INPUT`
from any trigger — point a webhook listener at it and nothing else changes.

## Keeping it quiet enough to leave on

An automated reviewer earns its place by being ignorable:

- the automatic pass posts **only what blocks the merge**;
- a clean change gets **no comment at all** — the pipeline status already says it ran;
- there is **no summary note**; findings sit on the code;
- **one root cause, one thread**, even when the cause appears in several places;
- at most eight findings, and at most five of them minor.

The most common reason teams mute a bot reviewer is a wall of general notes in the activity feed.
Everything above is aimed at that.

## Security model

**The diff under review is untrusted input.** Anyone who can open a merge request can write
anything into a file the reviewer reads. Three properties follow, each of which took a real
mistake to learn:

1. **The reviewer holds no credential.** It runs with `Read Grep Glob` and two git reads, returns
   findings as data, and never calls the API. `GITLAB_ACCESS_TOKEN` is removed from its
   environment.
2. **A wrapper the model may invoke is not a boundary if the model can also write.** An earlier
   design scoped the reviewer to one posting script — and left it a `Write` tool, so it could
   overwrite that script and run it. Either the model cannot write, or the posting step is out of
   its reach; this design does both.
3. **A note body is not inert.** GitLab executes quick actions — `/close`, `/merge`, `/assign` —
   when a body has one on a line of its own, under the token's permissions. The poster refuses a
   body shaped that way.

The token is a project access token with `api` scope, Developer role. `CI_JOB_TOKEN` cannot create
merge request notes, which is why a project token exists at all.

## Cost and latency

| Control | Where | Effect |
|---|---|---|
| `CLAUDE_MODEL` | job variable | `claude-opus-5` reviews best; `claude-sonnet-5` is faster and cheaper |
| `CLAUDE_EFFORT` | job variable | `medium` for the automatic pass, `high` for the deep one |
| `CLAUDE_MAX_BUDGET_USD` | **project** variable | hard ceiling per review; defaults to 5.00 |
| `--max-turns`, `timeout` | job | bound a review that turns out harder than expected |

<<<<<<< HEAD
`CLAUDE_MAX_BUDGET_USD` is deliberately **not** declared in the job: a job-level variable outranks
a project-level one, so declaring it would make the project setting inert.
=======
GitLab ranks a project variable above a job variable, so a project-level `CLAUDE_MAX_BUDGET_USD`
wins whether or not the job declares one. The job leaves it undeclared anyway, so there is one
obvious place to look for the value rather than two that disagree.
>>>>>>> fix/gitlab-review-glab

## Operating it

**Required GitLab CI/CD variables**

| Variable | Masked | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | yes | The Claude API key |
| `GITLAB_ACCESS_TOKEN` | yes | Project access token, `api` scope. Without it the review runs and prints to the job log |
| `REVIEW_TRIGGER_TOKEN` | yes | Pipeline trigger token, for the mention sweep |
| `CLAUDE_MAX_BUDGET_USD` | no | Spend ceiling per review |

**The pipeline schedule** that drives the sweep sets `SWEEP_MENTIONS` to `true`. Without that
variable the sweep job does not run, so an ordinary scheduled pipeline cannot start reviews by
accident.

**Reading a failure.** The review job is `allow_failure: true`, because a probabilistic reviewer
must never block a merge — which also means **a green pipeline is not evidence the review worked**.
The job log is. It reports each thread it posted, and prints in full any finding it could not
anchor, so a posting failure loses the log line rather than the review.

**Trying a prompt change.** `examples/review-showcase/` carries a module with one defect of each
kind the guidelines prioritize. Open a merge request with it and compare what comes back.
