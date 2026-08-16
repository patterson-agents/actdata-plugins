---
name: review-mr
description: "Review a GitLab merge request against the shared rubric in the current session, and post the findings only on explicit confirmation."
---

# Review MR

Read and follow the canonical procedure in [../../commands/review-mr.md](../../commands/review-mr.md).

Treat the user's current request as the procedure input. Ignore the source file's YAML frontmatter
and any Claude-only invocation syntax. Use equivalent tools available on the current host, preserve
all safety checks, and resolve bundled resources from this plugin rather than the user's project.
