# 1. Fork `plugin-dev` rather than depend on it

- **Status:** Accepted
- **Date:** 2026-08-14

## Context

`actdata-plugins` needs plugin-development capability: reference material on plugin structure,
skills, commands, agents, hooks, MCP integration and settings, plus a workflow for creating a new
plugin.

Claude Code already ships exactly this as the `plugin-dev` plugin (version `0.1.0`, authored by
Daisy Hollman at Anthropic) — seven skills, three agents, and one guided command, roughly 524 KB of
well-structured reference content.

Reusing it directly was the obvious first choice. It is not workable, for one specific reason:
**generic plugin advice produces plugins that fail this repository's gate.**

Four constraints here are not visible to upstream:

1. A skill's directory name must equal its `SKILL.md` frontmatter `name`, in kebab-case. Upstream
   ships Title Case names (`name: Agent Development`) in kebab-case directories, so its own skills
   would fail our gate if vendored unchanged — and any skill authored from its guidance inherits
   the same defect.
2. A plugin must be registered in `.claude-plugin/marketplace.json` with a matching version, or it
   is not installable. Upstream treats marketplace registration as an optional final step
   ("Add marketplace entry (if publishing)").
3. Plugins live at `plugins/<name>/`. Upstream asks the user where to put the plugin.
4. This repository is Bun-only. Upstream's examples use `npm` and `npx`.

There is no extension point. A skill is a markdown file loaded verbatim; there is no way to layer
ACT's rules over upstream's text without editing the text.

## Options considered

| Option | Assessment |
|---|---|
| **Depend on upstream `plugin-dev`, add a thin ACT skill alongside** | Cheapest, and stays current automatically. Rejected: the ACT rules would live in a separate skill that may not load when the upstream skill does, so an author gets generic advice at exactly the moment they need the specific rule. The four constraints above are corrections to upstream's text, not additions to it. |
| **Fork verbatim, change only the name** | Rejected: keeps the diff minimal but leaves every reason for forking unaddressed. The Title Case names alone would fail the gate on day one. |
| **Fork and adapt** | Chosen. |
| **Write from scratch** | Rejected: discards 524 KB of good reference content to avoid a manageable maintenance obligation. |

## Decision

Fork `plugin-dev@0.1.0` into `plugins/act-plugin-dev/` and adapt it to this repository's
conventions.

Accept explicitly that this is a **fork, not a dependency**: it does not track upstream, and
re-syncing is a manual diff.

## Consequences

**The obligation this creates.** Upstream will change and this will not follow. To keep re-syncing
tractable, `plugins/act-plugin-dev/README.md` carries an "Upstream and divergence" section
recording the exact source path, the upstream version, every change made, and — importantly — the
changes deliberately *not* made. That section is part of the fork's contract; letting it go stale
is the failure mode that turns a manageable fork into an unmaintainable one.

**Divergence was kept deliberately narrow.** Six of the seven `SKILL.md` files differ from
upstream by exactly one line (the frontmatter `name`). All substantive ACT content is concentrated
in three places: a new section at the top of `plugin-structure/SKILL.md`, a rewritten
`commands/create-plugin.md`, and additions to `agents/plugin-validator.md`. A future re-sync can
therefore take upstream's `references/` and `examples/` wholesale and re-apply a small, known set
of edits.

**The emoji rule was scoped rather than applied blindly.** This repository forbids emoji on
ACT-authored surfaces. Applying that to the vendored `references/` and `examples/` would have
touched 30-plus files, ballooning the diff against upstream, to strip characters that function as
semantic DO/DON'T markers and terminal status output in content that is not a brand surface. The
rule was scoped to ACT-authored files instead, and `scripts/verify-all.sh` deliberately carries no
emoji check because a mechanical gate cannot distinguish the two cases.

**Upstream defects are fixed here and diverge silently.** The vendored copy had conversational text
committed into an agent system prompt, and unmatched code fences in three agents. Those are fixed
in the fork. If upstream fixes them differently, a re-sync will conflict on exactly those lines —
which is the correct outcome, and is why they are listed separately in the divergence table.

**Licensing is unresolved.** `[TBD: the license Anthropic applies to the bundled `plugin-dev`
plugin has not been confirmed.]` This is recorded in `LICENSE` and must be resolved before this
repository is distributed anywhere beyond Patterson Companies.
