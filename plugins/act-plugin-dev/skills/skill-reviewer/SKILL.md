---
name: skill-reviewer
description: "Review an agent skill for structure, triggering, progressive disclosure, and instruction quality."
---

# Skill Reviewer

Read and follow the canonical procedure in [../../agents/skill-reviewer.md](../../agents/skill-reviewer.md).

Treat the user's current request as the procedure input. Ignore the source file's YAML frontmatter
and any Claude-only invocation syntax. Use equivalent tools available on the current host, preserve
all safety checks, and resolve bundled resources from this plugin rather than the user's project.
