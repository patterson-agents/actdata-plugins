# Local

Reviewing before the change ever reaches a pipeline. Nothing is installed for the first option —
it already exists.

## In a session

Claude Code ships `/code-review` as a built-in. It reviews the branch's commits ahead of upstream
plus uncommitted changes, runs as a background subagent with its own context, and takes a target:
a path, a PR number, a branch, or a range such as `main...my-feature`.

| Flag | Effect |
|---|---|
| `--fix` | Applies findings to the working tree after the review |
| `--comment` | Posts findings as inline PR comments |
| effort level (`low` through `max`) | Trades coverage for confidence; `low` and `medium` report only high-confidence findings |

> [!NOTE]
> The built-in reads `CLAUDE.md` but **does not read `REVIEW.md`**. Where the repository's review
> policy lives in `REVIEW.md`, invoke `/code-reviews:review` instead — reading and applying those
> layers is exactly what it adds. The two otherwise overlap heavily, and the built-in's multi-agent
> verification is stronger on generic bug-finding.

Because a background review's `--fix` edits land outside session checkpoints, `/rewind` will not
undo them. Use git.

## As a pre-push hook

Copy `templates/pre-push` to `.git/hooks/pre-push` and mark it executable, or point an existing
hook manager (lefthook, husky, `core.hooksPath`) at it.

The hook calls whichever agent CLI is already on `PATH` — `claude`, `codex`, or `copilot` — and
skips silently when none is found. There is no configuration and no path to set: a tool that is not
installed simply does not run.

Two properties worth stating to the user:

- **Advisory by default.** Findings print and the push proceeds. A hook that blocks on a
  probabilistic reviewer strands people at the worst moment.
- **`.git/hooks` is per-clone and unversioned.** Each contributor installs it themselves, which is
  the argument for a hook manager whose config is committed.

`git push --no-verify` bypasses it, as with any hook.

## Which to reach for

| Situation | Use |
|---|---|
| Mid-work, want a second opinion | `/code-reviews:review` or `/code-review` in the session |
| About to push a branch | The pre-push hook |
| Reviewing someone else's PR locally | `/code-reviews:review <pr-number-or-range>` |
| Every change, without anyone remembering | A CI surface, not this one |

A local review is a convenience for the author. It is not a substitute for a pipeline review,
because it only runs when someone chooses to run it.
