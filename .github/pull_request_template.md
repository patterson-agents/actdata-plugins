# Summary

<!-- One or two sentences: what changes, and why. -->

## Type of change

- [ ] New plugin
- [ ] New skill, command, agent, or hook in an existing plugin
- [ ] Change to existing plugin content
- [ ] Repository furniture (scripts, CI, docs, governance)
- [ ] Fix

## The gate

- [ ] I staged my changes (`git add -A`) **before** running the gate. The validators read tracked
      files via `git ls-files`; on unstaged work they measure almost nothing and pass trivially.
- [ ] `sh scripts/verify-all.sh` prints `VERIFY-ALL: PASS`.
- [ ] `claude plugin validate .` is clean.

## Conventions

- [ ] Every new or renamed skill has a `SKILL.md` frontmatter `name:` identical to its directory
      name, in kebab-case.
- [ ] Any new plugin is registered in `.claude-plugin/marketplace.json` with a `relevance` block,
      and appears in the root `README.md` catalog table.
- [ ] Versions match between `plugin.json` and the `marketplace.json` entry for every plugin I
      touched.
- [ ] Intra-plugin paths use the literal `${CLAUDE_PLUGIN_ROOT}`, not a resolved absolute path.
- [ ] Bun only — no `npm`, `npx`, `yarn`, or `pnpm` in commands or examples, and no lockfile other
      than `bun.lock`.
- [ ] No new binaries (fonts, PDFs, Office documents, archives, rasters over 50 KiB).
- [ ] Nothing is written to `/tmp`; scratch uses `.tmp/`.
- [ ] No emoji on ACT-authored surfaces (READMEs, manifests, commands, agents, docs).
- [ ] Commit messages follow conventional commits and carry no AI attribution.

## Dependencies

- [ ] No new third-party dependency, **or** I scored it with
      `socket package shallow npm pkg:npm/<name>@<version> --markdown` and pasted the result below.

<!-- Paste socket output here if applicable. Call out any dimension under 90. -->

## Vendored or forked content

<!-- Skip if not applicable. -->

- [ ] I updated the "Upstream and divergence" section of the affected plugin's README so the fork
      stays re-syncable.

## Gaps

<!-- List any [TBD] markers this PR adds, and who needs to resolve them. A [TBD] is a question to
     escalate, not a defect to hide -- adding one is fine, leaving it undocumented is not. -->

## Verification

<!-- What you actually ran and what it printed. Not what you expect it would print. -->
