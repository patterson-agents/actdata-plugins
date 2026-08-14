# Security Policy

## Reporting a vulnerability

Report suspected vulnerabilities in `actdata-plugins` privately, never through a public GitHub
issue.

Use GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability)
on this repository ("Security" tab, then "Report a vulnerability") if it is enabled. That flow
creates a private draft advisory visible only to maintainers and gives you a secure channel to
attach reproduction detail.

If it is not enabled here, report through Patterson's internal security contact.

> [!CAUTION]
> `[TBD: the Patterson-wide security contact or mailbox has not been recorded in this
> repository.]` Do not report a vulnerability publicly while this is unresolved — escalate
> through your normal Patterson security channel instead.

Please include, where you can:

- The affected plugin, skill, agent, command, or script.
- Reproduction steps or a minimal example.
- The potential impact as you understand it — what an attacker could actually do, not just what
  looks unusual.

## What is in scope

- The plugin manifests, skills, agents, and commands under `plugins/`.
- `.claude-plugin/marketplace.json` — in particular anything that would cause an agent to install
  or trust something unintended.
- The validator scripts under `scripts/` and the CI configuration under `.github/`.
- This repository's supply chain. It currently has a near-empty dependency footprint, and the two
  validators in `scripts/` deliberately import only `node:*` builtins so the gate itself is not a
  supply-chain surface.

## Particular attention: prompt content is executable

A plugin in this repository is mostly **instructions to an agent**. A malicious or careless edit to
a `SKILL.md`, an agent system prompt, or a slash command is not inert text — it changes what an
agent will do on someone else's machine, with that person's credentials.

Treat the following as security-relevant, not merely stylistic:

- Instructions that tell an agent to exfiltrate file contents, environment variables, or
  credentials to any network destination.
- Instructions that suppress confirmation prompts, or that encourage running commands without
  showing them to the user.
- A hook that blocks or rewrites tool calls without a documented off switch.
- An MCP server configured over plain HTTP or WS rather than HTTPS or WSS.
- An absolute path where `${CLAUDE_PLUGIN_ROOT}` belongs — it can point at a directory the plugin
  author did not intend on a different machine.

## Dependencies

Before adding or upgrading any third-party package:

```sh
socket package shallow npm pkg:npm/<name>@<version> --markdown
```

Flag anything scoring under 90 on any of the five dimensions (supply chain, maintenance, quality,
vulnerability, license) and get confirmation before installing. Read the `[high]`/`[middle]`/`[low]`
alerts line as well.

## Out of scope for this file

- Vulnerabilities in ACT Data products or infrastructure that a plugin here happens to *describe*.
  Report those through the normal channel for that system.
- Upstream defects in Anthropic's `plugin-dev`, from which `plugins/act-plugin-dev/` is forked.
  Report those to Anthropic. If a defect has security impact *as vendored here*, report it here as
  well so the fork can be patched independently.

## Response

This repository does not commit to a response-time service level agreement.
`[TBD: no vulnerability-response SLA has been set for this repository.]` Reports are triaged by the
owning team in [`CODEOWNERS`](CODEOWNERS) for the affected path.
