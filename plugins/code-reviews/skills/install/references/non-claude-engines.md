# Non-Claude engines

The review methodology is provider-agnostic prose, so any agent that accepts a prompt and can read
files can run it. What changes between engines is only the invocation.

The pattern is the same everywhere: **point the engine at the guidance files and let it read them.**
Do not paste the rubric into the invocation, and do not build a wrapper that assembles a prompt —
the files are already on disk in the repository being reviewed.

A workable prompt, verbatim, for any engine:

```text
Review the changes on this branch against the review guidance in this repository.
Read, in order: REVIEW.md, then ACT_CODE_REVIEW.md and any file it references with @.
Report only findings that name a concrete failure scenario and cite path:line.
Print the findings; do not modify any file.
```

## docker-agent

A declarative runner: a YAML file names a model, an instruction, and toolsets. Provider-agnostic —
swapping `model:` swaps vendors — and the binary is standalone, so no Docker daemon is involved
despite the name.

Copy `templates/review-agent.yaml`, set `model:`, and run it headless:

```sh
docker-agent run --exec review-agent.yaml --safety restricted
```

The shipped toolset is read-only on purpose: filesystem reads and a fixed `git log` command, with
no shell, no network, and no MCP. The diff under review is untrusted input to an unattended model,
and the toolset is what bounds a prompt-injected run — the approval flag governs prompting, the
toolset governs capability.

Pin the release rather than tracking latest; headless flags and event shapes move between versions.

## Codex

```sh
codex exec "<the prompt above>"
```

Verify flags against `codex exec --help` for the installed version before committing them to a
pipeline.

## Copilot CLI

```sh
copilot -p "<the prompt above>"
```

Same caveat. Note that a prompt passed as an argument is bounded by the operating system's
per-argument limit, so a very large diff needs the engine's stdin mode where one exists.

## Where these fit

| Engine | Reasonable use |
|---|---|
| docker-agent | A pipeline that must not depend on any single vendor, or one running a local model |
| Codex, Copilot CLI | A team already standardized on that CLI |
| Claude Code | Everything else — it is the only engine whose review skills this plugin can invoke directly |

None of these post comments on their own. Where a review must land on a merge request, use a
surface whose harness provides the posting tools: `gitlab-ci.md`, `github-actions.md`, or
`github-managed.md`.
