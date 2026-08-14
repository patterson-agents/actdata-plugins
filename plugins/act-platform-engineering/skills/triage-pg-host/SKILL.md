---
name: triage-pg-host
description: "Run a broad read-only triage of a PostgreSQL host across system, storage, drives, database, replication, and kernel layers."
---

# Triage Pg Host

Read and follow the canonical procedure in [../../commands/triage-pg-host.md](../../commands/triage-pg-host.md).

Treat the user's current request as the procedure input. Ignore the source file's YAML frontmatter
and any Claude-only invocation syntax. Use equivalent tools available on the current host, preserve
all safety checks, and resolve bundled resources from this plugin rather than the user's project.
Read site configuration from `.agents/act-platform-engineering.local.md`; fall back to the legacy
`.claude/act-platform-engineering.local.md` only when the portable file is absent.
