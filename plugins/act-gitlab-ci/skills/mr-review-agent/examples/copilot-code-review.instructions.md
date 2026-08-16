---
applyTo: "**"
---

# Code review instructions

These instructions apply to automated code review of pull requests.

Review only the changed lines and the minimum surrounding context needed to judge them. Look for,
in priority order:

1. Correctness: logic errors, off-by-one, inverted conditions, unhandled null or undefined values,
   broken error propagation, behavior that differs from what the name or documentation promises.
2. Security: injection (SQL, shell, path, template), secrets or tokens in code, missing
   authorization checks, unsafe deserialization, SSRF, insecure defaults.
3. Concurrency and state: race conditions, unguarded shared state, missing idempotency where
   retries occur, resource leaks.
4. Error handling: swallowed exceptions, empty catch blocks, errors logged but not surfaced,
   fallbacks that hide failure.
5. API contracts: breaking changes to public interfaces, schema or serialization drift,
   incompatible migrations.

Do not comment on:

- Style or formatting that a linter or formatter already enforces.
- Preferences with no concrete failure mode.
- Lines the pull request did not touch, unless the change breaks them.
- The same root cause more than once; comment at the most representative location.

For each issue, state what breaks and under which conditions, and make the comment concrete enough
to act on without follow-up questions. Grade severity conservatively: reserve blocking language for
incorrect behavior, security holes, or data loss; phrase likely-but-conditional problems as
warnings; mark minor issues as nitpicks the author may reasonably ignore.
