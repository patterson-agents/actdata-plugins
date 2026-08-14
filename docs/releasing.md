# Versioning and releasing

How versions work here, and what is not yet decided.

> [!NOTE]
> This repository has never cut a release. There are no git tags, and everything sits at `0.1.0`.
> The sections below separate **what is enforced today** from **what needs deciding**, rather than
> describing a process that does not exist.

## Table of contents

- [Where versions live](#where-versions-live)
- [What is enforced](#what-is-enforced)
- [Choosing a version](#choosing-a-version)
- [Bumping a plugin](#bumping-a-plugin)
- [What a user actually gets](#what-a-user-actually-gets)
- [Open questions](#open-questions)

---

## Where versions live

Three distinct kinds, and only two of them are related:

| Version | File | Means |
|---|---|---|
| Marketplace | `.claude-plugin/marketplace.json` top level | The catalog's own version |
| Plugin manifest | `plugins/<name>/.claude-plugin/plugin.json` | That plugin's version |
| Catalog entry | The plugin's entry in `marketplace.json` | The version the catalog advertises |

The **second and third must match**. The first is independent.

Current state: every one of them is `0.1.0`.

## What is enforced

`scripts/verify-all.sh` step 4 fails the build when a plugin's `plugin.json` version disagrees with
its catalog entry:

```text
<name>: version 0.2.0 in plugin.json but 0.1.0 in marketplace.json
```

The reason is that the disagreement is otherwise silent: the catalog advertises one version and the
install delivers another, and nothing surfaces it to the user.

Nothing else about versioning is enforced. Semver discipline, changelogs and tags are all conventions
at best — see [Open questions](#open-questions).

## Choosing a version

Semver, applied to what a *plugin consumer* experiences. The useful question is not "did the files
change" but "will this surprise someone who already installed it".

| Bump | When |
|---|---|
| **Patch** `0.1.0 → 0.1.1` | A fix with no interface change. A corrected command, a clarified skill body, a typo in a reference. |
| **Minor** `0.1.0 → 0.2.0` | New capability, backward compatible. A new skill, command or agent. A new optional settings field. |
| **Major** `0.1.0 → 1.0.0` | A break. See below. |

### What counts as a break in a plugin

Less obvious than in a library, because the interface is partly conversational:

- **Renaming or removing a command, agent or skill.** Anyone with it in a runbook or an alias loses it.
- **Changing a settings file's schema** so an existing one stops working.
- **Changing a command's arguments** incompatibly.
- **Adding a required settings field.** A working install starts asking questions.
- **Changing what a script does to a system**, or its exit codes.

Deliberately *not* breaking:

- Rewording a skill body. The knowledge changed; the interface did not.
- Adding a `references/` file.
- Broadening a skill description so it triggers more often — though narrowing one so it triggers
  *less* can be, if someone depended on the old behaviour.

### The 0.x caveat

Everything is `0.1.0`, and under semver a `0.x` version signals that the interface is not yet stable.
That is currently accurate. It also means the major-bump rules above are theoretical until a `1.0.0`
is cut, which is one of the open questions.

## Bumping a plugin

```sh
# 1. Both files, same commit
$EDITOR plugins/<name>/.claude-plugin/plugin.json      # "version"
$EDITOR .claude-plugin/marketplace.json                # that plugin's entry

# 2. Update counts if components were added or removed
$EDITOR plugins/<name>/README.md                       # badges, component tables
$EDITOR README.md                                      # catalog row, top badges

# 3. Verify
git add -A
sh scripts/verify-all.sh
claude plugin validate .
claude plugin validate plugins/<name>

# 4. Commit
git commit -m "chore(<name>): bump to 0.2.0"
```

Bump both files in the **same commit**. A commit where they disagree is a commit that fails the gate,
which means a bisect lands on a broken build for reasons unrelated to what is being bisected.

### Version the plugin, not the repository

A change to one plugin bumps that plugin. It does not bump the others, and it does not bump the
marketplace. Plugins are installed individually and version independently.

## What a user actually gets

Worth understanding before designing a release process around it:

```sh
claude plugin marketplace add patterson-agents/actdata-plugins
claude plugin install act-platform-engineering@actdata-plugins
```

The catalog is read from the repository. There is no registry between the two, no build artefact and
no publish step. **A merge to the default branch is the release**, for anyone who re-adds the
marketplace or installs fresh.

Two consequences:

- Version numbers are documentation, not distribution. They tell a reader what changed; they do not
  gate what is delivered.
- Anything merged is live for the next install. There is no staging point between merge and users.

That is why the gate runs on every push rather than at a release boundary. There is no later moment
at which to catch something.

## Open questions

Each is a real decision nobody has made. They are `[TBD]` rather than assumed.

**`[TBD: whether releases are tagged, and in what format.]`**
No tags exist. If plugins version independently, per-plugin tags such as
`act-platform-engineering/v0.2.0` are one option; a repository-level tag is another and fits the
"merge is the release" model badly.

**`[TBD: whether a changelog is kept, and at what granularity.]`**
No `CHANGELOG.md` exists at either level. Conventional commits make one generatable, which is an
argument for per-plugin changelogs generated from commit scopes.

**`[TBD: what the marketplace's own top-level version means, and when it changes.]`**
It is `0.1.0` and has never moved. Candidates: it tracks catalog structure, or it is vestigial and
should be removed.

**`[TBD: whether a plugin may be removed from the catalog, and what a consumer sees if it is.]`**
Relevant before anything reaches `1.0.0`.

**`[TBD: whether `main` is always installable, or whether a release branch is wanted.]`**
Today, merging makes a change live for the next install. That is fine while the audience is internal
and small; it is worth revisiting before it is not.

## Related

| Topic | Where |
|---|---|
| The version-consistency check | [`verification.md`](verification.md#4-marketplace-registration-and-version-consistency) |
| Commit conventions | [`CONTRIBUTING.md`](../CONTRIBUTING.md) |
| What a marketplace entry needs | [`architecture.md`](architecture.md#two-manifests) |
