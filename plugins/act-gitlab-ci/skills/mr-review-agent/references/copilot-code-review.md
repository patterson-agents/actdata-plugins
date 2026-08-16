# GitHub Copilot native code review

How the same review rubric reaches GitHub Copilot's built-in pull-request reviewer, which runs on
GitHub's side with no pipeline, engine, or script from this plugin.

## Mechanism

Copilot code review reads repository custom instructions from the PR's head branch:

| File | Scope |
|---|---|
| `.github/copilot-instructions.md` | Repository-wide, all Copilot features |
| `.github/instructions/<name>.instructions.md` | Path-specific via `applyTo` frontmatter; supported by Copilot code review and the coding agent |

The shipped template `examples/copilot-code-review.instructions.md` is the second kind with
`applyTo: "**"`: the rubric's criteria, exclusions, and severity discipline rephrased for a
reviewer that posts its own native review comments. The findings JSON contract does not apply
here -- Copilot formats its own output -- so the instructions carry the judgment, not the schema.

Frontmatter options:

- `applyTo: "<glob>[, <glob>...]"` -- which files the instructions cover. `"**"` covers the
  repository; narrower globs (for example `app/models/**/*.rb`) scope review guidance to a
  subtree, and several instruction files can coexist.
- `excludeAgent: "code-review"` restricts a file to the coding agent only; omit it so both use
  the instructions.

## Installation

`/act-gitlab-ci:setup-mr-review copilot` copies the template to
`.github/instructions/code-review.instructions.md` in the target repository. Two conditions are
outside the file's control and worth stating to the user:

1. Copilot code review must be enabled for the repository or organization, and the
   "use custom instructions" toggle under Settings, Copilot, Code review must be on.
2. Instructions take effect for pull requests whose **head branch contains the file** -- reviews
   of branches cut before the file merged do not see it.

## Keeping the surfaces aligned

The instructions file is a manual restatement of `review-rubric.md`, not a generated artifact.
When the rubric changes, update the instructions file in the same change; the divergence to watch
for is severity language, which the rubric defines precisely and prose restatements erode.

GitLab has no equivalent instruction-file hook: its built-in reviewer surface is limited to
GitLab Duo, which is configured product-side. On GitLab, this plugin's CI job is the automated
reviewer.
