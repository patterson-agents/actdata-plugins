@REVIEW.md

# ACT review layer

Organization-wide review conventions, layered on top of this repository's own policy above. Where
the two disagree, this file wins.

> [!NOTE]
> The `@REVIEW.md` import on the first line is expanded by the `code-reviews` plugin and by the
> `CLAUDE.md` memory system. It is **not** expanded by Anthropic's managed Code Review, which reads
> `REVIEW.md` alone. On that surface, install flattens both layers into `REVIEW.md`.

## Durable, auditable work

Prefer repo-local scratch (a gitignored `.tmp/`) over `/tmp`. The point is not the path: work an
agent or a script produces — test output, fetched artifacts, generated content — should survive a
reboot and be inspectable by a human, and ephemeral system temp directories defeat both. This is a
guideline rather than an absolute; a container with a read-only root filesystem may leave `/tmp`
as the only writable place. Flag `/tmp` in a tracked file when a repo-local path would have worked.

The same reasoning applies to plans and specs: keep them in the repository (a `specs/` or openspec
tree) rather than in a developer's private plans directory, so the plan that produced a change is
reviewable alongside the change itself.

## Supply chain

A new or upgraded third-party dependency is Important unless the change shows it was scored:

```sh
socket package shallow npm pkg:npm/<name>@<version> --markdown
```

Flag any dimension scoring under 90, naming which one — a low quality score on a build-time
dependency is not the same risk as a low supply-chain or vulnerability score.

## Repository hygiene

- **Conventional commits**: `<type>(<scope>): <summary>`.

## Instructions are not output

Text describing *how the work was requested* must not appear in the artifact. Flag any of these in
a shipped file: second person addressed to one reader, "as requested" or "per your instruction",
session status such as "nothing is enabled yet", a count or path taken from one machine used as a
test fixture, or a comment recounting how a bug was found rather than what the code does.

## Tone

Direct, specific, neutral. This governs wording only: it does not change which findings are
reported, how they are graded, or the requirement that each names a concrete failure scenario and a
suggested fix.
