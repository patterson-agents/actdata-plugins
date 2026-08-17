# Review showcase

A fixture for demonstrating the automated merge request review, and for checking that a change to
the reviewer's prompt still catches what it used to.

`entitlements.ts` is a small, realistic access-control helper carrying one planted defect of each
kind `REVIEW.md` asks the reviewer to prioritize. Each is a bug a careful colleague would catch on
a first read, not a puzzle.

> [!IMPORTANT]
> The defects are deliberate. Do not "fix" them here, and do not copy this module into anything
> real. A security scanner flagging it is the fixture working.
>
> The file itself carries only a one-line pointer to this README. It deliberately does **not**
> announce that it is defective: a reviewer told the defects are intentional correctly declines to
> report them, which is exactly what happened the first time this fixture said so in a banner.

| Function | Kind | The defect |
|---|---|---|
| `isActive` | Correctness | Compares milliseconds to seconds, so every seat looks active — including expired ones |
| `hasSeat` | Correctness | `return` on the first non-matching seat, so only the first seat is ever considered |
| `buildQuery` | Security | Interpolates the caller's tenant into SQL, so a crafted tenant id reads another tenant's rows |
| `recordUsage` | Concurrency | Read-modify-write on a shared counter with an `await` in the middle, so concurrent calls lose increments |
| `auditLog` | Security | Writes the whole request, headers included, so any bearer token lands in the log |

## Running it as a demo

From a clone that has the GitLab remote (`git remote -v` shows it — add it with
`git remote add gitlab <url>` if not):

```sh
git switch -c demo/entitlements
mkdir -p src && cp examples/review-showcase/entitlements.ts src/entitlements.ts
git add src/entitlements.ts
git commit -m "feat(entitlements): add seat and quota helpers"
git push gitlab demo/entitlements -o merge_request.create
```

Copying the file rather than opening the merge request against `examples/` matters: it puts the
module in the diff **without** this README, so the reviewer judges the code on its own terms, the
way it would judge a real change.

The `code-review` job runs automatically. Expect threads anchored to the lines above, each naming
the failure, with an Apply-able suggestion where the fix is one line.

To show the mention path, comment `@act-code-review please take another look`. The scheduled sweep
acknowledges the comment with an emoji and posts a fresh review within its interval.

## What "good" looks like

The reviewer is doing its job when the threads:

- sit on the exact line, not on the file or in the activity feed;
- name the input or state that triggers the failure, rather than describing the code;
- carry an Apply-able suggestion when the fix is one line;
- stay silent about style, and about anything `scripts/verify-all.sh` already enforces;
- appear once per root cause, even where a cause shows up in several places.

A clean change should produce **no** comments at all. Silence is the design, not a failure.

## When the fixture itself is wrong

Run it and read what comes back. The first version of this file claimed `isActive` compared a
`Date` to a number and therefore always failed; the reviewer pointed out that JavaScript coerces
the `Date` through `valueOf`, so the comparison was correct and the case tested nothing. Treat a
finding against this directory as a finding, not as noise.
