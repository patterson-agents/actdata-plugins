---
name: create-plugin
description: "Create a plugin for the actdata-plugins marketplace. Use when asked to create, scaffold, package, register, or validate a new marketplace plugin."
---

# Create Plugin

Read and follow the canonical procedure in [../../commands/create-plugin.md](../../commands/create-plugin.md).

Treat the user's current request as the procedure input. Ignore the source file's YAML frontmatter
and any Claude-only invocation syntax. Use equivalent tools available on the current host, preserve
all safety checks, and resolve bundled resources from this plugin rather than the user's project.

For a portable plugin, create all three manifests: `.claude-plugin/plugin.json`,
`.codex-plugin/plugin.json`, and root `plugin.json`. Register it in the Claude, OpenAI, and Copilot
marketplaces. Put reusable behavior in `skills/`; treat Claude commands and agents as optional host
adapters. Keep versions identical everywhere and run the repository compatibility gate.
