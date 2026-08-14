---
name: assess-kernel
description: "Assess Linux kernel, sysctl, transparent huge pages, I/O scheduler, NUMA, and process limits on a database host."
---

# Assess Kernel

Read and follow the canonical procedure in [../../commands/assess-kernel.md](../../commands/assess-kernel.md).

Treat the user's current request as the procedure input. Ignore the source file's YAML frontmatter
and any Claude-only invocation syntax. Use equivalent tools available on the current host, preserve
all safety checks, and resolve bundled resources from this plugin rather than the user's project.
Read site configuration from `.agents/act-platform-engineering.local.md`; fall back to the legacy
`.claude/act-platform-engineering.local.md` only when the portable file is absent.
