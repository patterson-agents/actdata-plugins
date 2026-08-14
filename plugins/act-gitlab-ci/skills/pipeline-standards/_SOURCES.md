# Provenance

## What this is

The `pipeline-standards` skill is a **translation**, not a primary source.

| Field | Value |
|---|---|
| Derived from | Patterson CI/CD Pipeline Standards |
| Source article | ServiceNow IT Standards and Guidelines, `sys_kb_id=c70e79833b650f107f43b50236e45a7d` |
| Source owner | Infra CloudOps |
| Source implementation | `patterson-engineering:cicd-pipeline-standards` |
| Translated by | This plugin, for GitLab CI |
| Authoritative for ACT | **No** |

## Why this needs stating

The source standard was written for Azure DevOps and GitHub. Translating it to GitLab required
mapping platform concepts, and a mapping is an interpretation. Nobody at the standard's owning team
has reviewed this translation.

Anything here may be wrong in a way the source is not. Confirm with the standard's owner before
treating a clause as binding.

## The GitLab conflict

**The source standard does not permit GitLab.**

Its version-control clause reads: *"Use **Azure DevOps or GitHub**. Nothing else."* Its
approved-software list names GitHub (enterprise managed org only; public repositories require
approval) and Azure DevOps (approval required). GitLab appears on neither.

Two consequences:

1. A GitLab pipeline is an **exception** to this standard, not an implementation of it. Whether that
   exception exists, and who granted it, is not something this skill can answer.
2. **GitLab's built-in scanners are not approved.** GitLab SAST, Dependency Scanning, Secret Detection
   and Container Scanning do not appear on the approved list. Under the source's own decision rule, an
   unlisted tool requires review. A pipeline aiming at compliance disables the native scanners and
   wires in Checkmarx, GitLeaks and Trivy, which is a real and non-obvious cost of the exception.

This conflict is recorded rather than resolved. Resolving it is a decision for the standard's owner.

## What was translated, and how

| Source concept | GitLab mapping | Confidence |
|---|---|---|
| Branch policy `minimumApproverCount` | Approval rules / `approvals_before_merge` | High -- the number 2 is platform-neutral |
| Required status checks | Required job success on the MR pipeline | High |
| One organisation, teams not orgs | One top-level group with subgroups | High |
| Service connection | `id_tokens:` OIDC plus per-environment CI/CD variables | Medium -- GitLab has no direct equivalent object |
| `authenticationScheme: WorkloadIdentityFederation` | `id_tokens:` block | Medium |
| Standardised templates | `include: project:` or the CI/CD component catalogue | Medium -- the source names no template location |
| Environments and approvals | `environment:` with protected environments | Medium |
| Build once, promote same artifact | `artifacts:` with a `needs:` DAG | High |

**Unchanged, because they are platform-neutral:** all seven required scans and their named tools; the
two-approver minimum and the five required checks; pipeline as YAML in the application repository with
the GitOps repository as the only permitted split; build-once and promote; unit tests; centralised
artifact repository; blue-green, canary and rolling; automated rollback; post-deploy smoke test;
secrets never in code and a dedicated secrets manager.

**Carried over without a GitLab analogue:** production and non-production workloads must never share
a subscription. That is a cloud landing-zone control, unaffected by the CI platform.

## Gaps that remain gaps

The source marks these `[TBD]` and this translation does not fill them:

- No DAST tool is named.
- No container base image or registry list is enumerated.
- No rotation period for the b2c and vendor-integration credential exceptions, and no named approver.
- No preference between Vault and a cloud-native secrets manager, and no rotation interval.
- No named product or location for the centralised artifact repository.
- No mapping of deployment strategy to environment tier, no rollback trigger conditions, no
  smoke-test coverage requirement.
- No statement on whether the two approvers may include the author, whether code owners are required,
  or whether stale-approval dismissal is mandatory.
- No review cadence for the standard itself.

Additionally absent from the source, so absent here: artifact retention period, test coverage
threshold, severity or CVSS gating threshold for scan failure, build timeout, and any protected-branch
or branch-naming list.

## Maintainer rules, carried over

1. Do not add requirements that are not in this file or in `references/`. If the standard does not
   cover something, say so and mark it `[TBD]`.
2. Validator scripts under `scripts/` must only enforce rules quoted in `references/`. A rule with no
   citation is a bug.
3. A clean validator run means "nothing obvious found", not "compliant".

## A note on lineage

This repository's governance documents were deliberately written without references to the source
organisation. This skill reintroduces that lineage, confined to this directory and labelled
throughout, because encoding a standard without naming its source would be worse: it would present
derived rules as though they originated here.
