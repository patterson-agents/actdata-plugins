# Build, artifacts, deployment and promotion

Derived from the Patterson CI/CD Pipeline Standards. See `../_SOURCES.md`.

---

## Build

| Rule | Detail |
|---|---|
| Build model | **One build, one or more artifacts** |
| Promotion | Build once, promote **the same artifact** through every environment |
| Testing | **Unit testing** is required |
| Storage | Artifacts go to the **centralised artifact repository** |

**Rebuilding per environment is a violation, even when the source commit is identical.** The point is
that the thing tested in staging is byte-for-byte the thing that reaches production. Two builds of
the same commit can differ through dependency resolution, base image drift, or build-time
environment, and each difference is untested.

In GitLab: `artifacts:` on the build job, and a `needs:` DAG so downstream jobs consume that artifact
rather than rebuilding. A pipeline with a `docker build` in both a staging and a production job
violates this regardless of how identical the two look.

`[TBD: the standard does not name the centralised artifact repository product or location.]`

## Deployment

| Rule | Detail |
|---|---|
| Approved strategies | **blue-green, canary, rolling.** Nothing else. |
| Rollback | **Automated rollback is required** |
| Post-deploy | **Smoke test** after every deployment |

Automated rollback is the clause most often skipped, usually because rollback exists as a documented
manual procedure. A manual rollback is a person following steps during an incident, which is exactly
when it is slowest and most error-prone.

`[TBD: the standard does not state which strategy applies to which environment tier, nor rollback
trigger conditions, nor required smoke-test coverage.]`

## Promotion

Sandbox, Dev, Test, Stage, Production.

| Tier | Change control |
|---|---|
| Sandbox | Minimal |
| Dev | Minimal |
| Test | Moderate |
| Stage | High |
| Production | Strict |

**Playbooks are required for Production only.**

In GitLab: `environment:` per deploy job, with protected environments and approval rules tightening
toward production.

## Subscription isolation

**Production and non-production workloads must never share a subscription.** The source records no
exception path for this.

This is a cloud landing-zone control rather than a CI one, and it carries over to GitLab unchanged --
the CI platform has no bearing on it.

## What the validator sees

It counts build steps and warns when there is more than one. It looks for a test keyword, a
deployment strategy, a rollback and a smoke test, but only evaluates the last three when the file
mentions deployment at all.

It cannot tell whether the artifact promoted to production is genuinely the one built earlier, only
whether more than one build step exists. A pipeline that rebuilds with an identical artifact name
passes the check while violating the rule.
