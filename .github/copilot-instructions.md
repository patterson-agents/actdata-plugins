# Repository instructions

This repository distributes ACT Data plugins for Claude Code, ChatGPT, Codex, and GitHub Copilot.
It is a catalog of agent workflows, not an application package.

- Keep plugin names, skill directories, commands, and agents in lowercase kebab-case.
- Keep each `skills/<name>/SKILL.md` frontmatter `name` identical to its directory.
- Register every shipped plugin in `.claude-plugin/marketplace.json`,
  `.agents/plugins/marketplace.json`, and `.github/plugin/marketplace.json`.
- Keep versions synchronized across all marketplace entries and the plugin's
  `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, and root `plugin.json`.
- Preserve `${CLAUDE_PLUGIN_ROOT}` only in Claude-specific components. Portable skills must resolve
  bundled resources from the installed plugin or skill directory.
- Store site configuration in `.agents/<plugin>.local.md`; support `.claude/<plugin>.local.md` as a
  legacy fallback. Never commit environment identifiers or credentials.
- Use any modern JavaScript package manager (npm, pnpm, yarn, or bun) for the devDependencies.
  `package-lock.json` is the lockfile CI installs from; other managers' lockfiles are gitignored
  and must not be committed. The validators under `scripts/` run with `node` (v24+).
- Use `apply_patch` for edits and run `sh scripts/verify-all.sh` before considering a change done.
- Do not commit fonts, archives, Office files, PDFs, or raster images over 50 KiB.
