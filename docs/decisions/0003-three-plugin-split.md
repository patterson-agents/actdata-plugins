# 3. Split the operational bundle into three plugins

- **Status:** Accepted
- **Date:** 2026-08-14

## Context

A single directory, `plugins/act-platform-engineering/`, arrived containing 33 files: eight role
agents, nine diagnostic commands, eight output templates, a 24 KB command cheatsheet, an API
reference, a backlog dump and two scripts.

It was not a working plugin. There was no `plugin.json`, `SKILL.md` sat at the plugin root instead of
under `skills/`, and **none of the agents or commands had YAML frontmatter**, so nothing loaded at
all. It also had a `prompts/` directory, which is not a component type.

Restructuring it was unavoidable. The question was whether the result should be one plugin or several.

Three themes were visible in the content, and they had little to do with each other:

- **Infrastructure diagnosis** — PostgreSQL, ZFS, disks, kernel, Proxmox, observability
- **Work tracking** — the tracker's API, task-versus-issue conventions, a bulk-creation script
- **Writing practice** — status reports, assessment-document routing, house style

Separately, `plugins/gitlab-standards/` existed as an unregistered `claude plugin init` scaffold,
reserved for CI/CD scope, and a GitLab plugin was requested during the same work.

## Options considered

| Option | Assessment |
|---|---|
| **One plugin, topical skills** | Simplest to register and validate; one install gets everything. Rejected: someone who wants the tracker conventions has no interest in ZFS recordsize, and installs it anyway. Skill descriptions from unrelated domains compete for attention in every session. |
| **Two: infrastructure + everything else** | Rejected. "Everything else" is not a topic, and the writing conventions would sit under a name that does not suggest them. |
| **Three: by theme** | Chosen. |
| **Four or more, splitting infrastructure by subsystem** | Rejected. Postgres, ZFS and kernel tuning are genuinely one job on a database host — the ARC and `shared_buffers` interaction is unresolvable if the two live in different plugins. |

The GitLab work raised a parallel question:

| Option | Assessment |
|---|---|
| **New plugin, leave the scaffold** | Rejected: leaves a tracked, defective, unregistered scaffold next to a plugin covering the same ground. |
| **Fill the scaffold under its existing name** | Rejected: `gitlab-standards` understates the scope, which is CI jobs, an MCP server, the CLI and standards. |
| **Rename the scaffold and rewrite it** | Chosen. |

## Decision

Three plugins:

| Plugin | Scope |
|---|---|
| `act-platform-engineering` | Diagnosing and operating infrastructure: Postgres, ZFS, Linux hosts, Proxmox, observability, incident response |
| `act-work-tracking` | Zoho Projects mechanics, plus reporting and writing conventions |
| `act-gitlab-ci` | GitLab CI jobs, the GitLab MCP server, `glab`, pipeline standards |

`plugins/gitlab-standards/` was renamed to `plugins/act-gitlab-ci/` with `git mv`, and all eleven
scaffold files were deleted.

The `act-` prefix is retained throughout: it is the marketplace's namespace convention, matching the
existing `act-plugin-dev`, not leaked environment content.

## Consequences

**No cross-plugin references.** The three install independently, so a handoff pointing into another
plugin would break for anyone who installed only one. Every "hand off to X" names a skill or agent
within the same plugin.

This constrained the content layout in one visible way: the runbook and postmortem templates sit in
`act-platform-engineering`'s `incident-response` skill rather than with the other writing templates in
`act-work-tracking`, because the agent that uses them lives in the first plugin.

**`prompts/` dissolved.** Not being a component type, its eight files moved into `references/` inside
whichever skill owns each workflow. That mapping is what made the split fall out cleanly — templates
follow their workflow, and neither plugin reaches into the other.

**The scaffold deletion removed a dependency.** `plugins/gitlab-standards/package.json` declared
`@modelcontextprotocol/sdk`, which had never been Socket-scored, for a channel server whose only tool
returned the string `"sent"` without sending anything. Deleting the scaffold removed the only
third-party dependency in the plugin tree.

**Nothing was kept from the scaffold.** Its `.lsp.json` pointed at a language server named
`example-language-server`; its session hook parsed stdin and discarded it; its `plugin.json` carried
`"skills": ["./"]` alongside a `skills/` directory, which breaks auto-discovery. The rename preserved
the directory's history in git, not its contents.

**One open item was closed and one was created.** The README's recorded gap about `gitlab-standards`
is resolved. `plugins/code-review/`, `plugins/standards/` and `plugins/git-workflows/` remain empty
shells, still correctly unregistered.
