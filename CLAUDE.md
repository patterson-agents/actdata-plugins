# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repository is

`actdata-plugins` is a **Claude Code plugin marketplace**, not an application. There is no server,
no library, and no build step. The deliverable is `.claude-plugin/marketplace.json` plus the
plugins under `plugins/` that it points at.

The single most important consequence: **a plugin that is not registered in
`.claude-plugin/marketplace.json` does not exist.** It cannot be installed, however complete it
looks on disk. Creating a plugin directory and registering it are one task, not two.

## The gate

```sh
sh scripts/verify-all.sh
```

One script defines every mechanical invariant. CI (`.github/workflows/ci.yml`) and
`.githooks/pre-commit` both call it. It must print `VERIFY-ALL: PASS` before any change is done.

It checks: every discovered `run-tests.sh`, skill name equals directory name, plugin manifests
parse and match their directory, marketplace registration and version consistency, no tracked
binaries, the 2 MiB tracked-byte budget, and no expanded `${CLAUDE_PLUGIN_ROOT}`.

> [!IMPORTANT]
> `check-size.ts` and `check-no-binaries.ts` read **tracked** files via `git ls-files`. On
> unstaged work they measure almost nothing and pass trivially. Run `git add -A` before treating a
> green gate as meaningful.

Also run, for the manifest schema itself:

```sh
claude plugin validate .
```

## Conventions that fail the build

| Rule | Detail |
|---|---|
| Skill name equals directory | `skills/foo/SKILL.md` must have `name: foo`, kebab-case. Title Case (`name: Foo Bar`) is the usual import defect and fails the gate. |
| Plugins at `plugins/<name>/` | `metadata.pluginRoot` is `./plugins`. |
| Version in two places | `plugin.json` and the `marketplace.json` entry must agree. |
| `${CLAUDE_PLUGIN_ROOT}` literal | Never write a resolved absolute path into a tracked file. |
| No binaries, 2 MiB budget | SVG exempt; rasters capped at 50 KiB. |

## Conventions checked in review

- **Prefer `.tmp/` over `/tmp`.** Work a session produces — test output, fetched artifacts,
  generated content — should survive a reboot and be inspectable, so scratch goes in the
  repository's gitignored `.tmp/` whenever the environment allows it. Keep plans and specs in the
  repository too, not in a private plans directory.
- **Conventional commits**, branch off `main`, never commit to `main` directly.
- **Score new dependencies** with `socket package shallow npm pkg:npm/<name>@<version> --markdown`
  before adding them. Flag anything under 90.

Individual developers and teams bring their own toolchain preferences (package manager, formatter,
shell); this repository does not prescribe them. The validators under `scripts/` run with `node`
(v24+) and import `node:*` builtins only, so they work regardless of package manager.

## Layout

```text
.claude-plugin/marketplace.json   # Claude Code catalog; a plugin is invisible without an entry
.agents/plugins/marketplace.json  # ChatGPT and Codex catalog
.github/plugin/marketplace.json   # GitHub Copilot catalog
REVIEW.md                         # repo review policy -- single source for every review surface
ACT_CODE_REVIEW.md                # ACT org review layer; imports REVIEW.md
plugins/<name>/
  .claude-plugin/plugin.json      # Claude manifest; no "skills": ["./"] when skills/ exists
  .codex-plugin/plugin.json       # OpenAI manifest
  plugin.json                     # Copilot manifest
  skills/<skill-name>/SKILL.md    # frontmatter name == directory name
  agents/*.md  commands/*.md  hooks/hooks.json
scripts/verify-all.sh             # the gate
scripts/check-size.ts             # node:* builtins only, run with node
scripts/check-no-binaries.ts
scripts/check-marketplace-compat.ts
scripts/tests/run-tests.sh        # fixtures generated into .tmp/, never committed
docs/assets/                      # placeholder brand marks -- see its README
docs/decisions/                   # ADRs
```

## Code review surfaces

`REVIEW.md` (repo policy) plus `ACT_CODE_REVIEW.md` (org layer) drive every review surface. The
`code-reviews` plugin's `review` skill reads both directly; `.github/workflows/claude-code-review.yml`
invokes that skill on pull requests; the `code-review` job in `.gitlab-ci.yml` does the same on
merge requests; `.github/instructions/code-review.instructions.md` is a flattened copy for GitHub
Copilot review. When `REVIEW.md` or `ACT_CODE_REVIEW.md` changes, regenerate the Copilot
instructions file (`/code-reviews:install`) rather than editing it by hand.

## Building a plugin

Prefer the guided workflow over doing it by hand — it registers the marketplace entry and runs the
gate as part of the process:

```text
/act-plugin-dev:create-plugin
```

`act-plugin-dev` also carries the reference skills (`plugin-structure`, `skill-development`,
`command-development`, `agent-development`, `hook-development`, `mcp-integration`,
`plugin-settings`) and the `plugin-validator` and `skill-reviewer` agents.

## Things that are deliberately unfinished

Do not "fix" these without asking; they are recorded gaps, not oversights.

- `docs/assets/` holds an **invented placeholder** wordmark. No ACT brand assets exist.
- `.gitlab/` is empty. No ACT GitLab CI conventions were available to base a pipeline on.
- `LicenseRef-ACT-Internal` is a provisional identifier; ACT's licensing posture is unconfirmed.
