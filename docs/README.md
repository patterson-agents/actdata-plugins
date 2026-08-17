<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/act-wordmark-white.svg">
  <img src="assets/act-wordmark.svg" alt="ACT Data" width="260">
</picture>

# Documentation

</div>

---

Documentation for `actdata-plugins`, ACT Data's plugin marketplace for Claude Code, ChatGPT,
Codex, and GitHub Copilot.

## Start here

| If you are | Read |
|---|---|
| **New to the repository** | [`onboarding.md`](onboarding.md) — environment, orientation, first tasks |
| **About to make a change** | [`../CONTRIBUTING.md`](../CONTRIBUTING.md) — the rules, stated as rules |
| **Trying to understand how it works** | [`architecture.md`](architecture.md) |
| **Stuck on an error** | [`troubleshooting.md`](troubleshooting.md) |
| **Working on the automated review** | [`code-review.md`](code-review.md) |

## The documents

| Document | Answers |
|---|---|
| [`onboarding.md`](onboarding.md) | How do I get set up, what do I read, and what should I work on first? |
| [`architecture.md`](architecture.md) | How does a marketplace work? What discovers what, and when? |
| [`verification.md`](verification.md) | What exactly does the gate check, and what does nothing check? |
| [`code-review.md`](code-review.md) | How does the automated review work, on every surface, and how do I operate it? |
| [`troubleshooting.md`](troubleshooting.md) | Something broke. What is it and how do I fix it? |
| [`releasing.md`](releasing.md) | How do versions work here, and what is still undecided? |
| [`glossary.md`](glossary.md) | What does this repository mean by that word? |
| [`decisions/`](decisions/) | Why is it like this, and what else was considered? |
| [`assets/`](assets/) | The brand marks, and their provenance |

## How these fit together

They are layered, and each avoids repeating the one below it.

```text
onboarding.md        orientation      "where am I, what do I do first"
        |
architecture.md      explanation      "how the machinery works"
verification.md      reference        "what is enforced, precisely"
code-review.md       reference        "how the automated review works"
        |
CONTRIBUTING.md      rules            "what you must do"
        |
troubleshooting.md   recovery         "it broke"
glossary.md          vocabulary       "what that word means here"
decisions/           rationale        "why, and what else was considered"
```

`CONTRIBUTING.md` lives at the repository root rather than here because it is the file a contributor
is pointed at by convention and by GitHub's own tooling.

## Conventions in this documentation

**GFM alerts for emphasis, never emoji.** `> [!NOTE]`, `> [!IMPORTANT]`, `> [!WARNING]`,
`> [!CAUTION]`. Emoji are forbidden on ACT-authored surfaces; vendored upstream reference content
under `plugins/*/skills/*/references/` and `examples/` is exempt.

**Tables where the content is a lookup**, prose where it is an argument. A bulleted list of full
sentences is prose that has been chopped up.

**`[TBD:]` rather than a guess.** Where a source is silent, the marker records the gap so it can be
escalated to whoever owns the answer:

```sh
grep -rn '\[TBD' docs/ plugins/
```

**Claims are verified, not asserted.** Version numbers, file paths, exit codes and behaviour
described here were checked against the repository rather than recalled. Where something was not
verifiable, it says so.

## Keeping this accurate

Documentation decays faster than code, because the people best placed to notice are the ones least
confident about correcting it.

If something here is wrong, stale or missing, change it in the same branch as the work that revealed
it. That is a `docs:` commit and needs no ceremony.

> [!NOTE]
> `[TBD: no review cadence is defined for this documentation. Until one exists, the pull request that
> fixes something is the review.]`

## Elsewhere

Not everything is under `docs/`, and knowing where else to look saves a search:

| Content | Location |
|---|---|
| Per-plugin documentation | `plugins/<name>/README.md` |
| Component authoring guidance | The `act-plugin-dev` skills |
| Repository overview and plugin catalog | [`../README.md`](../README.md) |
| Security policy | [`../SECURITY.md`](../SECURITY.md) |
| Code of conduct | [`../CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) |
| Review ownership | [`../CODEOWNERS`](../CODEOWNERS) |
| Issue and pull request templates | [`../.github/`](../.github/) |

> [!IMPORTANT]
> Component authoring — how to write a good skill, command, agent or hook — deliberately lives in the
> `act-plugin-dev` plugin rather than here. That content is itself a shipped product, loaded on demand
> while you work. Duplicating it into `docs/` would create two copies that disagree within a month.
