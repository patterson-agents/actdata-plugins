# Review showcase

A worked example of the automated merge request review, for demonstrating what the reviewer does
and for checking that a change to the prompt still catches what it used to.

`entitlements.ts` is a small, realistic module — the kind of access-control helper every product
grows — carrying defects of the four kinds `REVIEW.md` asks the reviewer to prioritize. Each is a
bug a careful colleague would catch on a first read, not a puzzle:

| Line | Kind | The defect |
|---|---|---|
| `expiresAt` comparison | Correctness | Compares a `Date` to a number, so every entitlement reads as expired |
| `hasSeat` early return | Correctness | Returns on the first non-matching seat, so only the first seat is ever considered |
| `buildQuery` | Security | Interpolates the caller's tenant into SQL, so a crafted tenant id reads another tenant's rows |
| `recordUsage` | Concurrency | Read-modify-write on a shared counter without a guard, so concurrent calls lose increments |
| `auditLog` | Security | Writes the full request body, including the bearer token, into the log |

## Running it as a demo

```sh
git switch -c demo/entitlements
cp examples/review-showcase/entitlements.ts src/entitlements.ts   # or anywhere in the tree
git commit -am "feat(entitlements): add seat and quota helpers"
git push gitlab demo/entitlements -o merge_request.create
```

The `code-review` job runs automatically on the merge request. Expect threads anchored to the lines
above, each naming the failure and — where the fix is a single line — carrying a suggestion block
with an Apply button.

To show the mention path, comment `@act-code-review please take another look` on the merge request.
The scheduled sweep picks it up within its interval and posts a fresh review.

## What "good" looks like

The reviewer is doing its job when the threads:

- sit on the exact line, not on the file or in the activity feed;
- name the input or state that triggers the failure, rather than describing the code;
- offer an Apply-able suggestion when the fix is one line;
- stay silent about style, and about anything `scripts/verify-all.sh` already enforces;
- appear once per root cause, even when a cause shows up in several places.

A clean change should produce **no** comments at all. Silence is the design, not a failure.
