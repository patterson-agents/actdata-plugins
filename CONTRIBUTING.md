# Contributing to actdata-plugins

`actdata-plugins` is ACT Data's Claude Code plugin marketplace: capability shipped as installable
plugins. This document is how a person or an agent proposes a change to it.

## The short version

```sh
git switch -c feat/my-change      # never work on main
# ... make the change ...
git add -A                        # the validators read TRACKED files -- stage before you verify
sh scripts/verify-all.sh          # must print VERIFY-ALL: PASS
claude plugin validate .
git commit -m "feat(scope): summary"
```

## Repository conventions

These are load-bearing, not stylistic. `scripts/verify-all.sh` enforces the ones that can be
checked mechanically; the rest are checked in review.

| Rule | What it means |
|---|---|
| **kebab-case** | Plugin names, skill directory names, command filenames, agent filenames, issue and PR template filenames. |
| **Skill name equals directory name** | A skill's directory name and its `SKILL.md` frontmatter `name:` must be the identical kebab-case string. This is the single most common defect when importing a skill written elsewhere, because Title Case names (`name: Plugin Structure`) are the norm outside this repository. The gate fails on a mismatch. |
| **Plugins live at `plugins/<name>/`** | Never at the repository root, never nested deeper. `marketplace.json` declares `metadata.pluginRoot: "./plugins"`. |
| **Registration is part of shipping** | A plugin with no entry in `.claude-plugin/marketplace.json` is invisible to `claude plugin install`. Every shipped plugin needs an entry with a `relevance` block. A plugin that is still a scaffold should stay unregistered — the gate recognises TODO placeholders and reports it as a draft rather than failing. |
| **Version in two places** | `plugins/<name>/.claude-plugin/plugin.json` and the plugin's `marketplace.json` entry must carry the same version. Bump both in the same commit; the gate compares them. |
| **`${CLAUDE_PLUGIN_ROOT}` stays literal** | Every intra-plugin reference uses the literal token, never an absolute path a tool happened to resolve it to on someone's machine. The gate greps for expanded forms and fails on them. |
| **Bun only** | `bun install`, `bun run`, `bunx`, `bun test`. `bun.lock` is the only lockfile; an `npm`, `yarn`, or `pnpm` lockfile in this repository is a bug to remove. |
| **No `/tmp`** | Nothing is created or stored under `/tmp` — not scratch files, not build intermediates, not test fixtures. Scratch lives in the repository's gitignored `.tmp/`. This is a Patterson house standard enforced by a workspace hook. |
| **No binaries** | No fonts, no PDFs, no Office documents, no archives, and no raster image over 50 KiB. SVG is exempt at any size. `scripts/check-no-binaries.ts` enforces this. Brand fonts are licensed through Adobe Fonts and must never be committed. |
| **2 MiB tracked-byte budget** | `scripts/check-size.ts` sums `git ls-files` byte sizes, not `du` output — `du` block-accounting overstates a repository's real size substantially. |
| **No emoji on ACT-authored surfaces** | READMEs, manifests, commands, agents, and docs use GFM alerts (`> [!NOTE]`, `> [!WARNING]`) and tables for emphasis. Vendored upstream reference content is exempt; see below. |
| **Conventional commits** | `<type>(<scope>): <summary>`, e.g. `feat(act-plugin-dev): add skill-reviewer agent`. Types in use: `feat`, `fix`, `docs`, `test`, `chore`, `refactor`. |
| **No AI attribution** | No `Claude-Session:` trailers, no "Generated with Claude Code" footers, no AI co-author lines in commits or pull requests. |

### The emoji exemption, stated precisely

The no-emoji rule is a **brand surface** rule. It applies to what this marketplace authors and
publishes. It does **not** apply to third-party reference material vendored into a plugin, where
check and cross marks are semantic DO/DON'T markers and shell scripts use them as terminal status
output. Stripping them would multiply the diff against upstream for no brand benefit.

Because of that exemption, `scripts/verify-all.sh` deliberately carries **no** emoji check — a
mechanical gate could not tell the two cases apart. The rule is enforced in review and by the
`plugin-validator` agent, which reports emoji as a minor finding.

## Adding a plugin

The supported path is the guided workflow, which creates the directory, writes the manifest,
registers the marketplace entry, and runs the gate:

```text
/act-plugin-dev:create-plugin
```

By hand, the checklist is:

1. `plugins/<name>/.claude-plugin/plugin.json` — `name` matching the directory, semver `version`,
   real `description`, `license`.
   Do **not** add `"skills": ["./"]` if the plugin has a `skills/` directory; that field is the
   single-skill template shape and breaks auto-discovery.
2. `plugins/<name>/README.md` — model on `plugins/act-plugin-dev/README.md`.
3. An entry in `.claude-plugin/marketplace.json` with `source: "./plugins/<name>"`, a `version`
   matching `plugin.json`, and a `relevance` block.
4. A row in the catalog table in the root `README.md`.
5. `sh scripts/verify-all.sh` printing `VERIFY-ALL: PASS`.
6. `claude plugin validate .` clean.

## Dependencies

Before adding, installing, or upgrading **any** third-party package, score it:

```sh
socket package shallow npm pkg:npm/<name>@<version> --markdown
```

Five scores come back (supply chain, maintenance, quality, vulnerability, license) on a 0-100
scale. **Flag anything under 90** and get explicit confirmation before installing, naming which
dimension is low — low *quality* on a build-time devDependency is a different risk from low
*supply chain* or *vulnerability*. Read the `[high]`/`[middle]`/`[low]` alerts line too; it is
often more actionable than the scores.

> [!NOTE]
> The two validators in `scripts/` import only `node:*` builtins by design. Keeping them
> dependency-free means the gate runs before `bun install` and cannot itself be a supply-chain
> surface.

## Test-first

`scripts/check-size.ts` and `scripts/check-no-binaries.ts` came with a TDD suite
(`scripts/tests/run-tests.sh`), and any new validator should too: write the failing fixtures
before the implementation exists, confirm they fail for the right reason (missing script, not a
typo), then implement.

Fixtures that need an oversized file or a font binary to prove a check works are **generated at
test-run time** into a throwaway directory under `.tmp/` and never committed — a committed
oversized tree or binary would itself trip the very check it exists to test.

`verify-all.sh` discovers every `run-tests.sh` in the repository automatically. Adding a suite
requires no edit to the gate.

## Pull requests

- Branch from `main`; never commit to `main` directly.
- One logical change per pull request.
- Run `sh scripts/verify-all.sh` locally before opening it. CI runs the same script — a red CI on
  something the local gate would have caught is wasted review time.
- Fill in the pull request template checklist honestly. An unchecked box with an explanation is
  more useful than a checked box that is not true.

Opt into the local pre-commit gate once per clone:

```sh
git config core.hooksPath .githooks
```

## Reporting a gap rather than filling it

When a source is silent on something a plugin would otherwise need to assert, write
`[TBD: what is missing]` rather than inventing an answer. A `[TBD]` is a question to escalate to
whoever owns the thing, not a defect to quietly resolve.

```sh
grep -rn '\[TBD' plugins/ docs/
```
