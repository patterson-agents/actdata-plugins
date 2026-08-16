---
description: Review a GitLab merge request against the shared rubric, in-session, and optionally post the findings
argument-hint: "[MR IID, MR URL, or a git range]"
allowed-tools: Read, Bash, Grep, Glob
---

# Review a merge request in-session

Apply the review rubric to a merge request (or a local range) and report findings in the
conversation. The same rubric drives the CI job and the git hook; this is the surface for
reviewing one MR on demand, with no pipeline involved.

## Resolve the target

From `$ARGUMENTS`:

- An MR IID or URL: use it directly.
- A git range (contains `..`): review the local diff of that range and skip the GitLab steps.
- Nothing: find the MR for the current branch with `glab mr view --output json`, and if there is
  none, fall back to the local diff against the default branch.

## Obtain the diff

Prefer, in order:

1. `glab mr diff <iid>` when the glab CLI is authenticated.
2. The API: `GET /projects/:id/merge_requests/:iid/changes` via `glab api`, which also returns
   `diff_refs` (needed later for posting inline).
3. A local `git diff <base>...<head>` when GitLab is unreachable.

Also fetch the MR title and description; intent matters when judging a diff.

## Apply the rubric

Read `${CLAUDE_PLUGIN_ROOT}/skills/mr-review-agent/references/review-rubric.md` and follow it
exactly: changed lines only, the listed defect classes in priority order, the exclusions, and the
blocker/warning/nit severity discipline. Read surrounding files from the checkout when a changed
line cannot be judged alone.

## Report

Present the findings in the conversation: a one-paragraph summary, then each finding as
`[SEVERITY] path:line -- title` with the failure scenario and a concrete suggestion. A clean
review says so explicitly. Never pad: an empty findings list is a valid, common outcome.

## Posting is opt-in

After reporting, offer to post the review to the MR -- and only proceed on an explicit yes:

- With the glab CLI or a `GITLAB_TOKEN` available, post one summary note. Append the marker line
  `<!-- code-reviews:mr-review sha=<head_sha> kind=summary -->` so the CI job's sticky-note
  logic recognizes and updates it instead of duplicating it. Say plainly that this marker also
  makes the CI review job treat the current head as already reviewed and skip its own run
  (including inline discussions) until the next push -- posting an in-session review supersedes
  the automated one for that revision. Inline positioned discussions from an interactive
  session are rarely worth the fragility; the CI job owns that surface.
- With no credentials, say so and leave the review in the conversation.

Never post without asking, and never include anything in the note that did not appear in the
reported findings.
