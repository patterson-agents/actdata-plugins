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

Past roughly five minor comments, summarize the remainder as a count rather than posting each one.
