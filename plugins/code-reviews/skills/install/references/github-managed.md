# GitHub, managed Code Review

Anthropic runs the review on its own infrastructure. No workflow file, no API key in the
repository, no runner minutes. This is the least work and the best default when the organization
qualifies.

## Prerequisites

- A Claude Code Team or Enterprise subscription. It is unavailable to organizations with Zero Data
  Retention enabled.
- An Owner or Primary Owner in the Claude organization, with permission to install GitHub Apps.

These are the user's to arrange; state them and stop if they are not met. Where the organization
does not qualify, `github-actions.md` is the equivalent self-hosted path.

## Steps the user performs

1. Open `claude.ai/admin-settings/claude-code`, find the Code Review section, click **Setup**.
2. Install the Claude GitHub App into the organization and grant it the target repositories.
3. Select which repositories to enable.
4. Set **Review Behavior** per repository:

| Mode | Runs | Cost |
|---|---|---|
| Once after PR creation | When a PR opens or is marked ready | One review per PR |
| After every push | On each push; resolves threads when issues are fixed | Multiplies by push count |
| Manual | Only on `@claude review` | Nothing until asked |

Manual mode suits high-traffic repositories. `@claude review always` opts a single PR into
push-triggered reviews without changing the repository default.

## What this repository must contain

`REVIEW.md` at the root. The managed product injects it verbatim into every agent in the review
pipeline as the highest-priority instruction block, which makes it the single most effective place
to tune what gets flagged.

> [!IMPORTANT]
> `REVIEW.md` is pasted verbatim: `@` imports are **not** expanded and referenced files are **not**
> read. An `ACT_CODE_REVIEW.md` layer is therefore invisible to this surface.

Flatten the layers so this surface sees both. Append the ACT layer's body — everything after its
`@REVIEW.md` line — to `REVIEW.md` beneath a marked section:

```markdown
<!-- BEGIN generated from ACT_CODE_REVIEW.md -- edit that file and re-run /code-reviews:install -->
...ACT layer body...
<!-- END generated from ACT_CODE_REVIEW.md -->
```

Tell the user this section regenerates and must not be hand-edited.

## What to expect

- Findings post as inline comments on the lines they concern, tagged Important, Nit, or
  Pre-existing, each with expandable reasoning.
- A **Claude Code Review** check run collects every finding in one severity-sorted table, and
  annotates the Files changed tab. It always completes neutral, so it never blocks a merge through
  branch protection.
- Reviews take roughly 20 minutes and are billed per run, scaling with diff size.

## Gating merges on findings

The check run never blocks. To gate in your own CI, read the machine-readable severity counts from
the last line of the check run's output:

```sh
gh api repos/OWNER/REPO/commits/<sha>/check-runs --jq '.check_runs[] | select(.name=="Claude Code Review") | .id'
gh api repos/OWNER/REPO/check-runs/CHECK_RUN_ID \
  --jq '.output.text | split("bughunter-severity: ")[1] | split(" -->")[0] | fromjson'
```

This returns counts per severity, for example `{"normal": 2, "nit": 1, "pre_existing": 0}`, where
`normal` is the Important count.

## Troubleshooting

| Symptom | Cause |
|---|---|
| No check run appears | The repository is not enabled, or the App lacks access to it |
| Check says issues found, no inline comments | Look at the check run Details table and the Files changed annotations; a line that moved rejects its inline comment |
| Review errored or timed out | Comment `@claude review` to retry. GitHub's **Re-run** button does not retrigger it |
| A spend-cap comment appears | The organization's monthly cap was reached; reviews resume next period or when an admin raises it |
