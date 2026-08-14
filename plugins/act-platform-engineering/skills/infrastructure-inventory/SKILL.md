---
name: infrastructure-inventory
description: This skill should be used when any platform-engineering task needs to know which hosts, databases, or services exist -- when the user says "assess the database", "check the primary", "which hosts do we have", "run this on the replica", "what is our topology", or names a role rather than a machine. It defines where the site inventory lives, how to read it, and the rule that a hostname or address is never invented or assumed. Load it before any command that targets a host.
version: 0.1.0
---

# Infrastructure Inventory

This plugin ships **no** hostnames, IP addresses, database names, or service endpoints. Not as
defaults, not as fallbacks, not as examples in a table. Every one of those values is site-specific
and lives in a settings file the operator writes.

This skill defines that contract. Every command and agent in the plugin depends on it.

## The rule

> [!IMPORTANT]
> Resolve a target from arguments first, then from the settings file. If neither supplies it, **ask
> the user**. Never invent, guess, or pattern-match a hostname, address, database name, or ID.

An invented hostname is worse than no hostname. A command that guesses `db-primary` and runs a
diagnostic against whatever answers is a command that produces confident findings about the wrong
machine.

## Where the inventory lives

`.claude/act-platform-engineering.local.md`, relative to the project root. It is gitignored: the
repository's `.gitignore` carries `.claude/*.local.md` precisely so a site inventory never lands in
version control.

Read it with the Read tool at the start of any host-targeting work. Do not cache it across
sessions; operators edit it as the estate changes.

## Resolution order

1. **An explicit argument.** `/act-platform-engineering:assess-postgres db-primary` targets
   `db-primary`, whatever the settings file says.
2. **The settings file**, matched by role. "assess the primary" resolves to the row whose Role
   column says `primary`.
3. **Ask.** State what is missing and offer to create the settings file from the template.

If the settings file is absent entirely, say so plainly and offer the template. Do not proceed with
a placeholder.

## Reading the file

The format is a Markdown document with three tables. Parse the ones the task needs; ignore the
rest. An operator may add sections, and unknown sections are not an error.

| Section | Supplies |
|---|---|
| `## Hosts` | Name, role, address, and notes for every machine in scope |
| `## Databases` | Database name and which host row it lives on |
| `## Services` | Observability endpoints, git host, VPN, and similar |

Roles are free text, but the commands in this plugin look for these conventional values: `primary`,
`replica`, `standby`, `hypervisor`, `app`, `observability`. When a role is ambiguous or several
rows match, list the candidates and ask rather than picking the first.

## Handling a partial inventory

Operators fill this in incrementally. A row with a name but no address is normal and means "this
host exists but I have not recorded how to reach it". Treat a blank cell as unknown, not as empty
string:

- Blank address, and the task needs to connect: ask for it.
- Blank role: do not infer one from the hostname.
- Host referenced in `## Databases` but absent from `## Hosts`: report the inconsistency.

## The template

Ship this to the user when the file is missing. It is also reproduced in the plugin README.

````markdown
# act-platform-engineering settings

Site inventory for the act-platform-engineering plugin. Not committed.

## Hosts

| Name | Role | Address | Notes |
|------|------|---------|-------|
|      |      |         |       |

## Databases

| Database | Host | Notes |
|----------|------|-------|
|          |      |       |

## Services

| Service | Endpoint | Notes |
|---------|----------|-------|
|         |          |       |
````

## What this skill deliberately does not do

It does not connect to anything, discover hosts on a network, or read `/etc/hosts`, SSH config, or
cloud metadata to populate the inventory. Host discovery is an operator decision with security
consequences; this plugin reads what it is told and nothing else.

For the assessment commands that consume this inventory, see the `postgres-operations`,
`zfs-storage`, `linux-host-tuning`, and `proxmox-virtualization` skills.
