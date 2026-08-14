---
name: plugin-validator
description: "Validate a marketplace plugin. Use when asked to check plugin structure, manifests, components, registration, or portability."
---

# Plugin Validator

Read and follow the canonical procedure in [../../agents/plugin-validator.md](../../agents/plugin-validator.md).

Treat the user's current request as the procedure input. Ignore the source file's YAML frontmatter
and any Claude-only invocation syntax. Use equivalent tools available on the current host, preserve
all safety checks, and resolve bundled resources from this plugin rather than the user's project.

Also validate `.codex-plugin/plugin.json`, root `plugin.json`, and the `.agents/plugins` and
`.github/plugin` marketplace entries. Names, versions, and source paths must agree across all three
hosts. Core workflows must be skills so ChatGPT does not depend on commands, agents, or hooks.
