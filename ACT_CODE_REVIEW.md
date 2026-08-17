@REVIEW.md

# ACT review layer

Organization-wide review conventions, layered on top of this repository's own policy above. Where
the two disagree, this file wins.

> [!NOTE]
> The `@REVIEW.md` import on the first line is expanded by the `code-reviews` plugin and by the
> `CLAUDE.md` memory system. It is **not** expanded by Anthropic's managed Code Review, which reads
> `REVIEW.md` alone. On that surface, install flattens both layers into `REVIEW.md`.

## Toolchain

- **Bun only.** `bun install`, `bun run`, `bunx`, `bun test`. An `npm`, `yarn`, or `pnpm` lockfile
  is a finding; `bun.lock` is the only lockfile.
- **No Python.** A `.py` file or an invocation of `python`, `pip`, `uv`, or `poetry` is a finding.
- **No `/tmp`.** Scratch files belong in a gitignored `.tmp/` inside the project.

## Supply chain

A new or upgraded third-party dependency is Important unless the change shows it was scored:

```sh
socket package shallow npm pkg:npm/<name>@<version> --markdown
```

Flag any dimension scoring under 90, naming which one — a low quality score on a build-time
dependency is not the same risk as a low supply-chain or vulnerability score.

## Repository hygiene

- **No AI attribution.** A `Claude-Session:` trailer, a "Generated with Claude Code" footer, or an
  AI co-author line in a commit message or pull request body is a finding.
- **Conventional commits**: `<type>(<scope>): <summary>`.
- **No emoji** on ACT-authored surfaces: READMEs, manifests, commands, agents, documentation. Use
  GitHub alerts and tables instead. Vendored upstream content is exempt.

## Instructions are not output

Text describing *how the work was requested* must not appear in the artifact. Flag any of these in
a shipped file: second person addressed to one reader, "as requested" or "per your instruction",
session status such as "nothing is enabled yet", a count or path taken from one machine used as a
test fixture, or a comment recounting how a bug was found rather than what the code does.

## Tone

Direct, specific, neutral. This governs wording only: it does not change which findings are
reported, how they are graded, or the requirement that each names a concrete failure scenario and a
suggested fix.
