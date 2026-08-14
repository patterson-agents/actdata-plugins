---
name: zoho-projects
description: This skill should be used when the user asks to "create a Zoho task", "draft an issue", "add this to the backlog", "file this in Zoho", "bulk create issues", "what's the difference between a task and an issue", or mentions Zoho Projects, the bugs API, portal IDs, project IDs, Zoho-oauthtoken, or turning assessment findings into tracked work items. Covers the task-versus-issue distinction, drafting templates, the API's quirks, and bulk creation.
---

# Zoho Projects

Turning work into tracked items, and the API quirks involved in getting them there.

## Configuration

Portal ID, project IDs, prefixes and the default assignee come from
`.agents/act-work-tracking.local.md`, falling back to the legacy
`.claude/act-work-tracking.local.md`. This plugin ships none of them.

If the file is absent, ask the user to create it from the template in the plugin README. Do not
guess an ID -- a plausible-looking portal ID sends work into someone else's tracker or, more often,
fails with an error that reads like an authentication problem.

## Tasks and issues are different things

This distinction drives everything else and is the most common source of badly shaped backlogs.

| | Task | Issue |
|---|---|---|
| Is | A high-level category or theme | A concrete, actionable unit of work |
| Answers | "What area of work is this?" | "What exactly needs doing?" |
| Carries priority | Yes | No -- priority lives on the containing task |
| Example | "Observability and Monitoring" | "Deploy the metrics collector to the four hosts missing it" |
| API path | `/tasks/` | `/bugs/` |

If the user describes something specific and finishable, it is an **issue**. If they describe an
area that will contain several pieces of work over time, it is a **task**.

Note the API asymmetry: issues are created through the **bugs** endpoint and return under a `bugs[]`
key, whatever the interface calls them.

## Drafting

Load the relevant template:

- `references/task-template.md` -- categories
- `references/issue-template.md` -- concrete work

Both follow the conventions in the `ops-reporting` skill's `references/writing-conventions.md`. The
two rules that matter most: no first or third person framing, and no priority language in prose.

## Check for duplicates first

Before drafting, query the project for existing items covering the same ground. A backlog with three
differently-worded versions of the same issue is worse than one with none, because each looks like
separate work when it is planned.

Use the projects API or the configured MCP tools to list open items and compare. Say what you
checked -- "no existing issue mentions the collector rollout" is a useful part of the draft.

## Creating

**One item:** draft it, show the user, create it after they confirm.

**Several items:** build a JSON file and use the bundled script:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/zoho-create.sh" --dry-run backlog.json
"${CLAUDE_PLUGIN_ROOT}/scripts/zoho-create.sh" backlog.json
```

`--dry-run` prints the intended API calls and needs no credentials or network access. Always run it
first: the script has no undo, and the rate limit means a failed bulk run can leave a half-created
backlog to reconcile by hand.

See `examples/sample-backlog.json` for the input schema.

The script needs `ZOHO_CLIENT_ID`, `ZOHO_CLIENT_SECRET`, `ZOHO_REFRESH_TOKEN`, `ZOHO_PORTAL_ID` and
`ZOHO_PROJECT_ID` in the environment for a real run. Supply them from a secrets manager, not from a
file on disk.

## API quirks worth knowing before debugging

See `references/zoho-api.md` for the full reference. The four that cost the most time:

1. The auth header is `Zoho-oauthtoken`, **not** `Bearer`.
2. Do not send `flag` when creating an issue. It fails with an error that does not name the field.
3. Descriptions are HTML. Use `<br>` for line breaks; literal newlines do not render.
4. Rate limit is 100 requests per 2 minutes. Sleep between calls on bulk runs.

## When to hand off

| Need | Skill |
|---|---|
| Weekly status, assessment documents, house writing style | `ops-reporting` |
| Deciding whether a finding is worth tracking at all | The `reporting-analyst` agent |
