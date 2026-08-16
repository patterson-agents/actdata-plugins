# What to report, and what to stay silent about

The checklist a review works through, then the standing list of things that must never be reported.

## Report

### Correctness

The largest category and the one worth the most attention.

- Inverted conditions, off-by-one bounds, wrong operator precedence.
- Unhandled `null` / `undefined` / empty-collection cases on a path that can produce them.
- A function whose behavior differs from what its name, signature, or documentation promises.
- State that is read before it is written, or written after it is read.
- Arithmetic that can overflow, divide by zero, or lose precision where precision matters.
- Early returns and `break`s that skip cleanup the rest of the path depends on.

### Security

Flag only with a concrete path from untrusted input to a dangerous sink. The attacker can be any
authenticated user, any network peer, or any untrusted data source — not only an anonymous
outsider.

- Injection: SQL, shell, path traversal, template, argument injection.
- Missing authorization. For each entry point ask: *if user A submits user B's resource ID, what
  stops them?* If the answer is "nothing", that is the finding.
- Secrets or tokens in code, logs, or error messages.
- Unsafe deserialization of attacker-controlled data.
- SSRF: a request whose destination is influenced by input.
- Disabled TLS verification, or crypto assembled by hand.

### Concurrency and state

- Read-modify-write without a guard where concurrent callers are possible.
- Missing idempotency where retries occur — a queue consumer, a webhook handler, a CI job.
- Resources acquired without a guaranteed release path.
- Shared mutable state captured by a closure that outlives its expected scope.

### Error handling

- Swallowed exceptions and empty catch blocks.
- A catch so broad it hides errors the author never considered. Name which ones.
- Errors logged but not surfaced, so a caller proceeds as though the call succeeded.
- Fallbacks that mask a failure rather than handling it, leaving the system quietly wrong.

### API contracts

- Breaking changes to a public interface without a version.
- Serialization or schema drift between producer and consumer.
- Migrations that are not backward compatible with the currently deployed code.

## Do not report

This list is not advisory. A finding matching any entry is dropped before the report is written.

- **Pre-existing issues** the change did not introduce, unless the change makes them reachable or
  worse. When one is genuinely worth surfacing, grade it `Pre-existing` and never as a blocker.
- **Anything a linter, formatter, type checker, or compiler catches.** Assume they run in CI. Do
  not run them to check.
- **Style and formatting**: naming preferences, import order, line length, comment wording.
- **Pedantic nitpicks a senior engineer would not raise in a real review.**
- **Generic quality observations**: "needs more tests", "could use better docs", "consider
  extracting a helper" — unless a specific guidance layer requires it, in which case quote the rule.
- **Speculative issues that depend on inputs or state you cannot show are reachable.**
- **Rules explicitly silenced in the code**, for example behind a lint-ignore comment with a reason.
- **Intentional changes in behavior** that are the evident point of the change.
- **The same root cause reported more than once.** Pick the most representative location.
- **Denial of service through missing limits** — absent timeouts, unbounded loops, no pagination.
  These are hardening suggestions, not defects, unless a guidance layer says otherwise.
- **Hardcoded non-secret configuration**: project IDs, table names, bucket names. Only real
  credentials count.

## The test a finding must pass

Before a finding is written down, it must answer all three:

1. **What breaks?** One sentence naming the defect.
2. **When?** Concrete inputs or state producing a wrong result, a crash, or a security consequence.
3. **Where?** A `path:line` citation in code that is actually visible, not inferred from a name.

A candidate that cannot answer all three is not a finding. Discard it silently.
