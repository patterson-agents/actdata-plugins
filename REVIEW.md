# Review instructions

Review policy for this repository. Anthropic's managed Code Review reads this file natively and
injects it as the highest-priority instruction block; the `code-reviews` plugin reads it on every
other surface. Keep it to instructions that change reviewer behavior — general project context
belongs in `CLAUDE.md`.

## What Important means here

This is a plugin marketplace: the deliverable is catalogs, manifests, and skills, and the install
experience is the product. Reserve Important for findings that break that product: a plugin
registered incorrectly or not at all, versions that disagree between a manifest and a catalog
entry, skill frontmatter whose `name` does not match its directory, YAML frontmatter that fails to
parse (it silently drops every field, including `allowed-tools`), a resolved absolute path where
`${CLAUDE_PLUGIN_ROOT}` belongs, or a change that breaks `scripts/verify-all.sh`. Style, naming,
and refactoring suggestions are Nit at most.

## Cap the nits

Report at most five Nits per review. If there are more, add "plus N similar items" to the summary
instead of posting them inline. If every finding is a Nit, open the summary with "No blocking
issues."

## Do not report

- Anything `scripts/verify-all.sh` already enforces mechanically: registration, version agreement,
  name-matching, tracked binaries, the size budget, expanded plugin roots.
- Generated files: compiled `*.lock.yml` workflows, package-manager lockfiles.
- Vendored upstream reference content, which lives under `plugins/*/skills/*/references/` and
  `plugins/*/skills/*/examples/`, including its style. This does not cover the top-level
  `examples/` directory, which is ACT-authored and reviewed like any other code.
- Scratch and fixtures under `.tmp/`.

## Always check

- A new or moved plugin is registered in all three catalogs (`.claude-plugin/marketplace.json`,
  `.agents/plugins/marketplace.json`, `.github/plugin/marketplace.json`) and carries all three
  host manifests.
- A version bump lands in both the plugin manifest and every catalog entry that names it.
- Bundled scripts are referenced through `${CLAUDE_PLUGIN_ROOT}`, never a relative path that
  breaks after install or a resolved absolute path.
- Shell scripts under `scripts/` stay POSIX sh; TypeScript validators import `node:*` builtins
  only, with no undeclared dependencies.
- Documentation that names counts, paths, or plugin lists still matches the tree it describes.

## Verification bar

A behavior claim needs a `file:line` citation in the source. An inference from a function or
variable name is not evidence and is not a finding.

## Re-review

After the first review of a change, suppress new Nits and report only newly introduced defects.

## Summary shape

Open the summary with a count by severity. Lead with "no blocking issues" when that is true.

<!-- BEGIN generated ACT layer. Flattened from ACT_CODE_REVIEW.md for surfaces that read
     REVIEW.md alone and do not expand imports. Edit ACT_CODE_REVIEW.md and regenerate
     (/code-reviews:install); hand edits below this marker are lost. -->

## ACT layer

- Prefer repo-local scratch (a gitignored `.tmp/`) over `/tmp` so generated work stays durable and
  inspectable; flag `/tmp` in a tracked file when a repo-local path would have worked. Keep plans
  and specs in the repository rather than a private plans directory.
- A new or upgraded third-party dependency is Important unless the change shows a
  `socket package shallow` score; flag any dimension under 90, naming which one.
- Conventional commits: `<type>(<scope>): <summary>`.
- Text describing how the work was requested must not appear in the artifact: no second person
  addressed to one reader, no "as requested", no session status, no machine-local counts or paths
  as fixtures.
- Tone: direct, specific, neutral — wording only; it changes nothing about what is reported.

<!-- END generated ACT layer. -->

