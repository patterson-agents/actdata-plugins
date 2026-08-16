# Review instructions

Review policy for this repository. Anthropic's managed Code Review reads this file natively and
injects it as the highest-priority instruction block; the `code-reviews` plugin reads it on every
other surface. Keep it to instructions that change reviewer behavior — general project context
belongs in `CLAUDE.md`.

Delete the sections that do not apply. Every heading below is optional.

## What Important means here

Reserve Important for findings that would break behavior, expose data, or block a rollback:
incorrect logic, unscoped database queries, credentials or personal data in logs, and migrations
that are not backward compatible. Style, naming, and refactoring suggestions are Nit at most.

## Cap the nits

Report at most five Nits per review. If there are more, add "plus N similar items" to the summary
instead of posting them inline. If every finding is a Nit, open the summary with "No blocking
issues."

## Do not report

- Anything CI already enforces: linting, formatting, type errors.
- Generated files and lockfiles.
- Test-only code that intentionally violates production rules.

## Always check

Repository-specific rules go here. They land more reliably in this file than in a long `CLAUDE.md`.

- New public endpoints have an authorization check scoped to the caller.
- Database queries are scoped to the caller's tenant.
- Log lines exclude email addresses, user identifiers, and request bodies.

## Verification bar

A behavior claim needs a `file:line` citation in the source. An inference from a function or
variable name is not evidence and is not a finding.

## Re-review

After the first review of a change, suppress new Nits and report only newly introduced defects.

## Summary shape

Open the summary with a count by severity. Lead with "no blocking issues" when that is true.
