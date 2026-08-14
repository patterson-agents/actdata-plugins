---
description: Draft a Zoho Projects task, meaning a high-level category that groups related issues
argument-hint: "[category or theme]"
allowed-tools: Read, Bash, Grep, Glob
---

# Draft a task

Create a high-level category that will contain issues.

## First, confirm it is a task

A task is a theme, not a unit of work. It carries the priority field; the issues beneath it carry the
concrete work.

The test: **could someone mark this done?** If yes, it is an issue -- use
`/act-work-tracking:draft-issue`. "Replace the failing drives" can be finished. "Infrastructure and
Hardware" cannot, and that is what makes it a task.

## Check the existing categories

List the project's current tasks first. A new category is only worth adding if a new issue would
obviously belong in it and obviously not in any existing one.

Roughly six to ten categories works for most estates. Too few and everything lands in a catch-all
nobody prioritises; too many and related issues get separated, so no category ever looks important
enough to staff.

## Draft it

Load the `zoho-projects` skill and follow `references/task-template.md`.

```text
Title:       [Domain or category name]
Description: [One or two sentences naming what falls under this category.]
Priority:    [Critical / High / Medium / Low / None]
```

The description is a scope statement. Someone filing a new issue should be able to read it and tell
whether their issue belongs here.

## Style

- Title is a noun phrase in title case.
- No em-dashes.
- No first or third person.

## Present, then create

Show the draft and wait for confirmation.

On confirmation, create it through the Zoho MCP tools, or append to a JSON file for the bundled
script:

```json
{
  "type": "task",
  "title": "Category name",
  "description": "What falls under this category.",
  "priority": "High"
}
```

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/zoho-create.sh" --dry-run backlog.json
```
