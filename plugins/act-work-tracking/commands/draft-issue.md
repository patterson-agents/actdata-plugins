---
description: Draft a Zoho Projects issue from a finding or request, checking for duplicates first
argument-hint: "[what the issue is about]"
allowed-tools: Read, Bash, Grep, Glob
---

# Draft an issue

Turn a finding, request or action item into a concrete tracked issue.

## First, confirm it is an issue

An issue is specific and finishable. If the subject is an ongoing area of work that will always
contain more work, it is a **task** -- use `/act-work-tracking:draft-task` instead.

The test: **could someone mark this done?**

## Check for duplicates

Before drafting, list open items in the project and compare. Use the configured Zoho MCP tools or the
projects API.

Three differently-worded versions of one issue is worse than none, because each looks like separate
work when the backlog is planned. Report what you checked, even when you find nothing.

## Draft it

Load the `zoho-projects` skill and follow `references/issue-template.md`.

```text
Title: [Action-oriented or state-describing phrase]

Description:
[Paragraph 1: the current situation. What is the problem or what has been observed?]

[Paragraph 2: what done looks like. What needs to happen, and what is the expected outcome?]

[Optional paragraph 3: context, dependencies, or who to work with.]
```

Both paragraphs earn their place. The first makes the issue legible to someone who was not in the
conversation. The second makes it possible to tell when it is finished -- an issue with only a
problem statement can be abandoned but not completed.

## Style

From the `ops-reporting` skill's `references/writing-conventions.md`:

- No em-dashes.
- No first or third person framing. "X is needed", not "I want" or "we should".
- No priority language in prose. Priority is a field on the containing task.
- Lead with the consequence rather than asserting severity.

## Present, then create

Show the draft and wait for confirmation. Do not create it unprompted.

On confirmation, either create the single item through the Zoho MCP tools, or append it to a JSON
file for the bundled script:

```json
{
  "type": "issue",
  "title": "Issue title",
  "description": "First paragraph.<br><br>Second paragraph."
}
```

Descriptions are HTML: `<br><br>` between paragraphs, because literal newlines do not render.

For a batch:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/zoho-create.sh" --dry-run backlog.json
"${CLAUDE_PLUGIN_ROOT}/scripts/zoho-create.sh" backlog.json
```

Always dry-run first. The script has no undo, and a run that trips the rate limit leaves a
half-created backlog to reconcile by hand.
