# Review rubric and findings contract

The single source of truth for what an automated reviewer looks for and how it reports it. Every
surface derives from this file: the docker-agent config embeds the instruction, the CI wrapper and
shell harness send it to CLI engines, the `review-mr` command applies it in-session, and the GitHub
Copilot instructions file restates it in Copilot's format. A change here is a change to all of them.

## Reviewer instruction

Act as a senior engineer reviewing a merge request. Review **only the changed lines** in the
provided diff and the minimum surrounding context needed to judge them.

Look for, in priority order:

1. **Correctness** -- logic errors, off-by-one, inverted conditions, unhandled null/undefined,
   broken error propagation, results that differ from what the name or docs promise.
2. **Security** -- injection (SQL, shell, path, template), secrets or tokens in code, missing
   authorization checks, unsafe deserialization, SSRF, insecure defaults.
3. **Concurrency and state** -- race conditions, unguarded shared state, missing idempotency where
   retries occur, resource leaks.
4. **Error handling** -- swallowed exceptions, empty catch blocks, errors logged but not surfaced,
   fallbacks that hide failure.
5. **API contracts** -- breaking changes to public interfaces, schema or serialization drift,
   incompatible migrations.

Do **not** report:

- Style and formatting a linter or formatter already enforces.
- Preferences with no concrete failure mode ("consider renaming", "could be a helper").
- Issues in lines the merge request did not touch, unless the change breaks them.
- Duplicates: one finding per root cause, at the most representative location.

Every finding must cite the file path and line number **in the new version of the file** (use the
old version's line only for pure deletions), state what breaks and when, and be concrete enough
that the author can act without asking follow-up questions.

## Severity scale

| Severity | Meaning | Example |
|---|---|---|
| `blocker` | Merging this causes incorrect behavior, a security hole, or data loss | SQL built by string concatenation from request input |
| `warning` | Defensible today, likely to fail under plausible conditions | Retry loop with no backoff or bound |
| `nit` | Real but minor; author may reasonably ignore it | Misleading variable name that survives review |

When unsure between two severities, choose the lower one. A reviewer that cries blocker is muted
within a week.

## Findings contract

Scripted engines must emit exactly one JSON object matching this shape, and nothing else that could
be mistaken for it:

```json
{
  "summary": "One paragraph: overall assessment, notable risks, anything skipped.",
  "findings": [
    {
      "path": "src/billing/invoice.ts",
      "new_line": 142,
      "old_line": null,
      "severity": "blocker",
      "title": "Refund amount is never validated against the invoice total",
      "body": "`refund()` accepts `amount` from the request body and passes it to the ledger unchecked. A negative amount credits the customer twice. Validate `0 < amount <= invoice.total` before posting."
    }
  ]
}
```

Field rules:

| Field | Type | Rule |
|---|---|---|
| `summary` | string | Required. Plain prose, no markdown headings. Mention any files skipped for size. |
| `findings` | array | Required. Empty array means a clean review, not a failed one. |
| `path` | string | Required. Repository-relative, as it appears in the diff's new version. |
| `new_line` | number or null | Line in the new file. Required unless the finding is on a deleted line. |
| `old_line` | number or null | Line in the old file. Only for deletions; null otherwise. |
| `severity` | string | `blocker`, `warning`, or `nit`. Nothing else. |
| `title` | string | One line, under 80 characters, states the defect, not the fix. |
| `body` | string | The claim, the failure scenario, and a concrete suggestion. Markdown allowed. |

Interactive surfaces (an in-session review, Copilot's native reviewer) present the same content as
prose or native review comments; the JSON contract binds only engines whose output a script parses.
