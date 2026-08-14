# 2. Ship no environment identifiers; read them from a site-local settings file

- **Status:** Accepted
- **Date:** 2026-08-14

## Context

`act-platform-engineering` and `act-work-tracking` were adapted from a working skill bundle written
for one specific estate. That bundle was useful precisely because it was specific: it named the
database primary, the hypervisor nodes, the replication targets, the tracker's portal and project
IDs, and the colleagues who owned each area.

Every one of those is an environment identifier, and they appeared in essentially every file —
including a `## Known Issues at ACT` section in all eight role agents.

Three problems with shipping them:

1. **They go stale silently.** A hostname in a plugin is a fact frozen at authoring time. When the
   estate changes, the plugin keeps asserting the old shape confidently.
2. **They make the plugin single-tenant.** A second team, or a second environment, cannot use it.
3. **A wrong default is worse than a missing one.** A command that defaults to a plausible hostname
   will eventually run a diagnostic against the wrong machine and report confident findings about it.
   The output looks correct, which is the worst available failure mode.

The third is the decisive one. The first two are inconvenience; the third produces wrong answers that
nobody questions.

## Options considered

| Option | Assessment |
|---|---|
| **Ship the identifiers as-is** | Defensible for an internal marketplace, and cheapest. Rejected: it makes the plugins single-tenant and leaves the wrong-default failure in place. |
| **Ship them as documented defaults, overridable** | Rejected. A default *is* the wrong-default failure. The whole risk is that a plausible value is used without anyone noticing it was assumed. |
| **Strip them, and have commands ask every time** | Rejected as the sole mechanism: correct but tedious, and tedium gets worked around by pasting values into prompts, which puts them back in an untracked, unreviewable place. |
| **Strip them; read from a gitignored site-local file; ask when it is absent** | Chosen. |

## Decision

The operational plugins ship **no** hostnames, addresses, database names, portal IDs, user IDs or
service endpoints. Not as defaults, not as fallbacks, not as illustrative table rows.

Site-specific values live in `.claude/<plugin-name>.local.md`, written by the operator.
`.gitignore` carries `.claude/*.local.md` so one cannot be committed by accident.

Every command and agent that needs a target follows one resolution order:

1. An explicit argument
2. The settings file
3. **Ask the user**

Never invent, guess, or pattern-match a value.

The contract is owned by one skill per plugin —
`act-platform-engineering/skills/infrastructure-inventory/` — which defines the file location, the
table schema and the rule. Sibling skills reference it by name rather than restating it.

## Consequences

**An unconfigured install asks questions.** This is the intended behaviour and needs saying out loud,
because it reads as a defect: running `/act-platform-engineering:assess-postgres` with no settings
file produces a question rather than an assessment. That is the design working.

**The plugins became reusable as a side effect.** The goal was correctness, not portability, but the
result installs cleanly into any Postgres and ZFS estate. The knowledge — thresholds, diagnostic
ordering, what a signal means — turned out to be the transferable part, and the identifiers were the
only thing tying it to one site.

**Documentation carries the template.** Each plugin's README ships the settings-file schema, because a
config-driven plugin with no documented config is unusable.

**Enforcement is not mechanical.** The gate cannot know which strings are environment identifiers; the
set is per-change. A targeted `git grep` is written per change instead, and this is a known gap.

The grep used when the plugins were built, for reference:

```sh
git grep -nEi '<addresses>|<hostnames>|<domains>|<ids>|<people>' -- plugins/
```

The one intended exception is author metadata in `plugin.json`, which is authorship rather than
environment.

**One near-miss is worth recording.** The first leak check scanned only the three plugin directories
and came back clean. Ten superseded source files were still staged under `plugins/.staging/`,
carrying the original backlog data, and were caught only by a later repository-wide check. Scope the
grep to the whole tree, not to the directories you believe you edited.
