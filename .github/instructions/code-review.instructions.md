---
description: 'Code review guidance for this repository'
applyTo: '**'
---

<!-- Generated from REVIEW.md and ACT_CODE_REVIEW.md by /code-reviews:install.
     Edit those files and re-run install; hand edits here are lost. -->

# Code review instructions

Review only the changed lines and the minimum surrounding context needed to judge them.

## Report

In priority order:

1. **Correctness**: inverted conditions, off-by-one bounds, unhandled null or empty cases, broken
   error propagation, behavior that differs from what a name or docstring promises.
2. **Security**: injection (SQL, shell, path, template), missing authorization, secrets in code or
   logs, unsafe deserialization, SSRF, disabled TLS verification. Flag only with a concrete path
   from untrusted input to a dangerous sink.
3. **Concurrency and state**: unguarded read-modify-write, missing idempotency where retries occur,
   resources without a guaranteed release path.
4. **Error handling**: swallowed exceptions, catches broad enough to hide unrelated errors, errors
   logged but not surfaced, fallbacks that mask failure.
5. **API contracts**: unversioned breaking changes, schema drift, migrations that are not backward
   compatible with deployed code.

## Do not report

- Anything a linter, formatter, type checker, or compiler already catches.
- Style, naming, and formatting preferences.
- Pre-existing issues this change did not introduce.
- Speculative problems that depend on inputs you cannot show are reachable.
- Generic observations such as "needs more tests" or "could use better docs".
- The same root cause in more than one place; comment at the most representative location.

## Every comment must

State what breaks, name the concrete inputs or state that break it, and suggest a specific fix.
A claim about behavior needs evidence in code that is visible in the diff or its context — an
inference from a function or variable name is not evidence.

## Severity

Reserve blocking language for changes that would produce incorrect behavior, expose data, or cause
data loss. Phrase likely-but-conditional problems as warnings. Mark minor issues as nitpicks the
author may reasonably ignore. When torn between two levels, choose the lower one.

## Volume

Report at most five minor comments per review; summarize any remainder as a count ("plus N similar
items") rather than posting each one. If every finding is minor, open the summary with "No blocking
issues."

## Re-review

After the first review of a change, suppress new minor comments and report only newly introduced
defects.

## Summary shape

Open the summary with a count by severity. Lead with "no blocking issues" when that is true.

## Repository invariants

This repository is a plugin marketplace; the install experience is the product. Always check:

- A new or moved plugin is registered in all three catalogs (`.claude-plugin/marketplace.json`,
  `.agents/plugins/marketplace.json`, `.github/plugin/marketplace.json`) and carries all three
  host manifests.
- A version bump lands in both the plugin manifest and every catalog entry that names it.
- Skill frontmatter `name` equals its directory name; YAML frontmatter parses (a parse failure
  silently drops every field, including `allowed-tools`).
- Bundled scripts are referenced through `${CLAUDE_PLUGIN_ROOT}`, never a relative or resolved
  absolute path.
- Shell scripts under `scripts/` stay POSIX sh; TypeScript validators import `node:*` builtins
  only, with no undeclared dependencies.

Do not report vendored upstream reference content under `plugins/*/skills/*/references/` and
`examples/`, generated `*.lock.yml` workflows, or anything `scripts/verify-all.sh` already
enforces mechanically.

## Organization conventions

- Prefer repo-local scratch (the gitignored `.tmp/`) over `/tmp` so generated work stays durable
  and inspectable; flag `/tmp` in a tracked file when a repo-local path would have worked.
- A new or upgraded dependency is blocking unless the change shows a `socket` score; flag any
  dimension under 90, naming which one.
- Conventional commits (`<type>(<scope>): <summary>`).
- Text describing how the work was requested must not appear in the artifact: no second person
  addressed to one reader, no "as requested", no session status, no machine-local counts or
  paths as fixtures.
