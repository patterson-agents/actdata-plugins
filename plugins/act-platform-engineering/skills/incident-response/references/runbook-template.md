# Runbook template

A runbook is a playbook for one specific operation: failover, restore from backup, replace a drive,
provision a user. It is written for someone other than the author to follow under pressure, possibly
at 3am, possibly having never done it before.

That reader is the whole design constraint.

---

## Structure

````markdown
# Runbook: [Specific operation]

| Field | Value |
|---|---|
| Last verified | YYYY-MM-DD |
| Owner | [Name] |
| Estimated time | [Realistic, including safety checks] |
| Risk level | Low / Medium / High |

## When to use this runbook

[A specific triggering condition, not a category. Not "for failover" but "when the primary has been
unresponsive for more than 5 minutes and the standby shows healthy replication".]

## When NOT to use this runbook

[Conditions where a different runbook applies, or where escalating beats executing.]

## Prerequisites

- [Required access: VPN, SSH key, sudo, console]
- [Required tools installed locally]
- [Information needed on hand: target host, IDs, credentials location]

## Safety checks before starting

- [ ] [A specific verification with a pass condition, e.g. "replication is streaming on the standby
      with replay_lag under 5s"]
- [ ] [Another check]

If any safety check fails, STOP and escalate to [person or channel].

## Steps

### 1. [Step name]

```bash
command --with --exact --flags
```

**Expected output:** [What success looks like]
**If it fails:** [What to do -- not "investigate"]

### 2. [Step name]

[... one action per step ...]

## Verification

- [ ] [A specific check proving the operation worked end to end]
- [ ] [Another]

## Rollback

1. [Step]
2. [Step]

If rollback is not possible, escalate to [person or channel].

## Common issues

### Issue: [Specific error message or symptom]

**Cause:** [Brief]
**Fix:**

```bash
fix-command
```

## Notification

- [ ] [Who to tell]
- [ ] [What record to update]
- [ ] [What documentation to revise if the procedure changed]

## Last verified

Executed in [test / production] on [date] by [person]. The procedure worked as documented.
````

---

## Style rules

- **Imperative voice.** "Run this command", not "you should run this command".
- **Real commands with real flags.** A generic example is useless under pressure. If a value is
  site-specific, name where to find it rather than inventing a placeholder that looks real.
- **Show expected output.** The reader needs to know whether it worked before continuing.
- **One action per step.** Never "run X and check Y".
- **Include rollback even when it seems unnecessary.** Especially then.
- **No em-dashes.** Use commas, parentheses, or restructure.

## The "last verified" field is the important one

A runbook that has never been executed is a hypothesis. A runbook last verified two years ago
describes an estate that no longer exists, and following it confidently during an outage makes
things worse.

Date it, and re-verify after any change to the systems it touches. An out-of-date runbook is more
dangerous than a missing one, because a missing one prompts someone to think.

## When to write one

- Any operational task done more than twice, or expected to recur
- Any task complex enough to forget a step under pressure
- Any task that needs handing to someone else
- Any post-incident remediation that produced a working procedure

## Where runbooks live

Somewhere the reader can reach *during the outage*. A runbook for a failover, stored only on a wiki
hosted on the cluster that just failed, is not a runbook.

Keep them in version control alongside the infrastructure code, and make sure at least one copy is
reachable when the primary estate is down.
