---
name: install
description: This skill should be used when the user asks to "set up automated code review", "install code review on this repo", "review every PR", "review every merge request", "add Claude code review to CI", "wire up a pre-push review hook", or "configure Copilot code review". It installs the review into an existing harness - GitHub Actions, Anthropic's managed Code Review, GitLab CI, local hooks, or a non-Claude engine - using each harness's own native mechanism and never a bespoke runner.
argument-hint: "[github-managed|github-actions|gitlab-ci|local|copilot|other-engine]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Install automated code review

Wire the `review` skill into a harness that already exists. This skill writes configuration and
copies templates; it never builds a runner and never handles a credential.

## 1. Establish the guidance files first

Every surface reads the same layers, so set them up before touching any harness.

1. If `REVIEW.md` is absent at the repository root, copy
   `${CLAUDE_PLUGIN_ROOT}/skills/review/templates/REVIEW.md` and cut it down to what the repository
   actually wants. Every heading in it is optional; a short file beats a thorough one.
2. If the repository is under ACT and `ACT_CODE_REVIEW.md` is absent, copy
   `${CLAUDE_PLUGIN_ROOT}/skills/review/templates/ACT_CODE_REVIEW.md`. It opens with `@REVIEW.md`,
   so it extends rather than replaces what step 1 produced.
3. Read `${CLAUDE_PLUGIN_ROOT}/skills/review/references/guidance-layering.md` and tell the user
   which of their chosen surfaces expand `@` and which need a flattened file.

## 2. Choose a surface

From `$ARGUMENTS`, or ask. More than one can be installed; they are independent.

| Surface | Use when | Reference |
|---|---|---|
| `github-managed` | GitHub, and the organization has Claude Code Team or Enterprise. No workflow file, no API key. | `references/github-managed.md` |
| `github-actions` | GitHub, and the review should run in your own CI with your own key | `references/github-actions.md` |
| `gitlab-ci` | GitLab merge requests | `references/gitlab-ci.md` |
| `local` | Before pushing, or on demand in a session | `references/local.md` |
| `copilot` | The repository is reviewed by GitHub Copilot's native reviewer | `references/copilot-native.md` |
| `other-engine` | docker-agent, Codex, or Copilot CLI drives the review | `references/non-claude-engines.md` |

Read the matching reference in full before writing anything. Each one states what the harness does
natively, what it cannot do, and the exact steps.

## 3. Install

Copy the template named by the reference, adapt it to the repository's existing conventions —
match the stage names in an existing `.gitlab-ci.yml`, match the trigger style of neighbouring
workflows — and keep every bound the template ships with. The timeouts, turn caps, and
non-blocking settings are cost and safety controls, not decoration.

Where a reference calls for a generated file, generate it with its header intact and tell the user
the regeneration command. A generated file edited by hand diverges silently.

## 4. Report what the user must do

Some steps cannot be done from here. List them explicitly rather than leaving them implied:

- **Credentials.** Name each variable or secret, where it is created, and how it must be scoped.
  Never read, write, or echo a value.
- **Console settings.** Enabling the managed product, choosing a trigger mode, or turning on
  Copilot's custom-instructions toggle are all outside the repository.
- **Fork exposure.** Say plainly that secrets must not be exposed to pipelines from forks: the
  reviewed diff is untrusted input to a model with the job's environment in reach.

## 5. Verify

Recommend a first run before the setup is trusted: open a test pull or merge request, confirm the
review appears, and read what it produced. A review that runs but reports nothing useful is a
guidance problem, and `REVIEW.md` is where it gets fixed.

## Resources

References: `github-managed.md`, `github-actions.md`, `gitlab-ci.md`, `local.md`,
`copilot-native.md`, `non-claude-engines.md`.

Templates: `claude-code-review.yml`, `gitlab-ci-review-job.yml`, `pre-push`,
`code-review.instructions.md`, `review-agent.yaml`.
