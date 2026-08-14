---
name: agent-creator
description: "Design a Claude Code custom agent. Use when asked to create, generate, or improve an agent or subagent definition."
---

# Agent Creator

Read and follow the canonical procedure in [../../agents/agent-creator.md](../../agents/agent-creator.md).

Treat the user's current request as the procedure input. Ignore the source file's YAML frontmatter
and any Claude-only invocation syntax. Use equivalent tools available on the current host, preserve
all safety checks, and resolve bundled resources from this plugin rather than the user's project.
