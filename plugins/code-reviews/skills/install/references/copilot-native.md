# GitHub Copilot native review

Copilot's own reviewer runs on GitHub's side. Nothing from this plugin executes; the entire
integration is a guidance file Copilot reads.

## Mechanism

| File | Scope |
|---|---|
| `.github/copilot-instructions.md` | Repository-wide, every Copilot feature |
| `.github/instructions/<name>.instructions.md` | Path-scoped via `applyTo` frontmatter; supported by Copilot code review and the coding agent |

Use the second. Copy `templates/code-review.instructions.md` to
`.github/instructions/code-review.instructions.md`.

Frontmatter:

```yaml
---
description: 'Code review guidance for this repository'
applyTo: '**'
---
```

- `applyTo` takes one or more comma-separated globs. `'**'` covers the repository; a narrower glob
  scopes guidance to a subtree, and several instruction files can coexist with different scopes.
- `excludeAgent: ["coding-agent"]` restricts a file to code review only. Omit it to let both use it.

## This file is generated

Copilot does not expand `@` imports, so it cannot follow `ACT_CODE_REVIEW.md` to `REVIEW.md`. The
instructions file is a flattened restatement of both layers, phrased for a reviewer that posts its
own native comments — so it carries the judgment, not the findings schema.

Generate it with its header intact:

```markdown
<!-- Generated from REVIEW.md and ACT_CODE_REVIEW.md by /code-reviews:install.
     Edit those files and re-run install; hand edits here are lost. -->
```

Tell the user the rule that matters: when the review layers change, regenerate. The failure mode is
silent divergence, where Copilot enforces last quarter's policy while everything else enforces
this quarter's.

## Two conditions outside the file

1. Copilot code review must be enabled for the repository or organization, and the **use custom
   instructions** toggle under Settings, Copilot, Code review must be on.
2. Instructions are read **from the pull request's head branch**. A PR branched before the file
   merged does not see it. Say this — it is the usual reason a correct file appears to do nothing.

## Scope honestly

This surface is configured, not executed, by the plugin. Copilot decides what to flag, in its own
voice, with its own severity vocabulary. The instructions file steers it; it does not control it.
Where an organization needs findings graded exactly as the rest of this plugin grades them, a
GitHub Actions or managed review is the surface that delivers that, and Copilot's reviewer is
complementary rather than equivalent.
