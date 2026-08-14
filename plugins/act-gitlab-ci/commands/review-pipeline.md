---
description: Review a GitLab pipeline against the derived standards, combining the checker with what it cannot see
argument-hint: "[path to .gitlab-ci.yml or directory]"
allowed-tools: Read, Bash, Grep, Glob
---

# Review a pipeline

Assess a `.gitlab-ci.yml` against the pipeline standards, and report honestly on what could not be
assessed.

## Run the checker

```bash
bun "${CLAUDE_PLUGIN_ROOT}/scripts/check-pipeline.ts" ${ARGUMENTS:-.gitlab-ci.yml}
```

Output is `LEVEL|file|line|rule|message`. Exit 0 clean, 1 errors, 2 could not evaluate.

## Then read for what it cannot see

The checker is a regex scanner. Load the `pipeline-standards` skill and read the pipeline yourself
for:

| Blind spot | What to do |
|---|---|
| `include:` and `extends:` | Follow them manually. Scans in templates read as missing. |
| UI-configured settings | Approval rules, protected branches and environments, masked/protected variables |
| `allow_failure: true` on a scan | It runs but gates nothing |
| Build-once compliance | More than one build step is detected; an identically-named rebuild is not |
| Least privilege | Not visible in the pipeline file at all |

If the pipeline uses `include:`, expect false "missing scan" findings and say so rather than
reporting them as violations.

## Credential findings lead

Regardless of discovery order, credential problems go first. See
`pipeline-standards/references/credentials-and-secrets.md`.

Check masked and protected separately. They are independent, and a credential that is masked but not
protected is readable by any job on any branch.

## Flag GitLab's native scanners

> [!IMPORTANT]
> If the pipeline uses GitLab's built-in SAST, Dependency Scanning, Secret Detection or Container
> Scanning templates, flag it: those are not on the approved tools list, which names Checkmarx,
> GitLeaks and Trivy. Report it as a finding **and** as an open question, since it follows from the
> standard being written for other platforms.

## If there is a Claude Code job

Check `--max-turns`, `timeout:`, concurrency, the `rules:` scope, and whether `--allowedTools` is
minimal. An unbounded AI job triggered by a comment lets anyone who can comment spend money.

## Output

Rank by severity. For each: file and line, rule, what is wrong, and the fix.

Group into three, and do not merge them:

1. **Confirmed** -- read and verified wrong
2. **Cannot verify here** -- in the UI or behind an include; say what to check and where
3. **Derived rule** -- rests on a clause translated from a standard written for another platform,
   unreviewed. Point at `pipeline-standards/_SOURCES.md`.

End by restating that a clean checker run means "nothing obvious found", not "compliant".
