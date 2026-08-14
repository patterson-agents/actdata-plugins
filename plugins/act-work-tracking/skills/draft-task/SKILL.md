---
name: draft-task
description: "Draft a Zoho Projects task that groups related issues under a durable work category."
---

# Draft Task

Read and follow the canonical procedure in [../../commands/draft-task.md](../../commands/draft-task.md).

Treat the user's current request as the procedure input. Ignore the source file's YAML frontmatter
and any Claude-only invocation syntax. Use equivalent tools available on the current host, preserve
all safety checks, and resolve bundled resources from this plugin rather than the user's project.
Read site configuration from `.agents/act-work-tracking.local.md`; fall back to the legacy
`.claude/act-work-tracking.local.md` only when the portable file is absent.
