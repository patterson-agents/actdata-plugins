---
name: pipeline-standards
description: This skill should be used when writing or reviewing a .gitlab-ci.yml, a GitLab merge request approval rule, a GitLab CI credential configuration or a GitLab deployment job, and when asked "does this .gitlab-ci.yml meet our standards", "how many approvers do we need on a GitLab MR", "which scans are required in our GitLab pipeline", "can I use a static credential in GitLab CI", or "how do we promote a build to production in GitLab". Applies pipeline standards translated to GitLab, with every clause marked as derived rather than authoritative. For the authoritative Azure DevOps and GitHub standard, use patterson-engineering:cicd-pipeline-standards instead.
---

# Pipeline standards (GitLab)

Build, test and deployment requirements, applied in order when reviewing or authoring a pipeline.

> [!CAUTION]
> **These rules are derived, not authoritative.** They are translated from a standard written for
> Azure DevOps and GitHub. See `_SOURCES.md` for provenance and for the conflicts the translation
> creates. Confirm with the standard's owner before treating any clause here as binding.

> [!WARNING]
> **The source standard does not permit GitLab.** Its version-control clause reads *"Use Azure DevOps
> or GitHub. Nothing else."* GitLab is not on the allowlist, and its built-in scanners are not on the
> approved-tools list either. A GitLab pipeline is therefore an exception to the standard, not an
> implementation of it. That question is open and belongs to the standard's owner, not to this skill.

## Meta rules, carried over verbatim

> Do not add requirements that are not in this file or in `references/`. If the standard does not
> cover something, say so and mark it `[TBD]`.

> Validator scripts under `scripts/` must only enforce rules that are quoted in `references/`. A rule
> with no citation is a bug.

Everything marked `[TBD]` in the source stays `[TBD]` here. Do not fill a gap by inference.

## 1. Version control

- **The source permits Azure DevOps or GitHub only.** GitLab requires an exception. See the warning
  above.
- **One organisation for all teams.** In GitLab terms: one top-level group, with subgroups. Not a
  separate top-level group per team.

## 2. Merge request policy

- **2 approvers.** Not one. Not the author plus a bot.
- Required checks, all of them: validation pipeline, container scanning, SAST, SCA, DAST.

In GitLab: approval rules (`approvals_before_merge` or a project approval rule) plus required job
success on the merge request pipeline.

`[TBD: the standard does not state whether the two approvers may include the author, whether code
owners are required, or whether stale-approval dismissal is mandatory.]`

## 3. Pipeline as code

| Rule | Detail |
|---|---|
| Format | YAML |
| Location | In the application repository |
| Permitted split | The GitOps pipeline may live in a separate repository. That is the only allowed split. |
| Templates | Standardised templates must be used. In GitLab: `include:` from a template project, or the CI/CD component catalogue. |

`[TBD: the standard does not name the location, version or contents of the standardised templates.]`

## 4. Required scans

Every pipeline must run all seven.

| Scan | Tool constraint |
|---|---|
| SAST | Checkmarx (approval required) |
| SCA | Checkmarx (approval required) |
| DAST | `[TBD: no DAST tool is named in the source standard]` |
| Secret scanning | GitLeaks (no approval needed) |
| API scanning | Checkmarx (approval required) |
| Container scanning | **Trivy or Checkmarx.** No other scanner. |
| IaC scanning | Checkmarx |

> [!IMPORTANT]
> **GitLab's built-in scanners are not approved.** GitLab SAST, Dependency Scanning, Secret Detection
> and Container Scanning do not appear on the approved-tools list. Under the source standard's
> decision rule, a tool that is not listed requires review. A "compliant" GitLab pipeline therefore
> disables the native scanners and wires in Checkmarx, GitLeaks and Trivy instead, which is a
> substantial and non-obvious cost of the platform exception.

Approved base images are also required.

Two tools that are **not** among the seven, and are easy to mistake for them: JFrog covers
third-party package security; Qualys is vulnerability scanning. Neither satisfies a CI scan
requirement.

The source notes that Checkmarx is slated to replace Trivy. Trivy remains approved today; new work
should account for the migration.

## 5. Credentials

- **Federated credentials only.** The only named exceptions are **b2c** and **vendor integration**.
- **Different credentials per environment.** Never shared across environments.
- **Least privilege.** Broad subscription-wide roles are a violation.
- **Production requires approval.**

In GitLab: `id_tokens:` for OIDC, per-environment CI/CD variables, and protected environments. See
the `ci-auth-providers` skill for the working shape of this.

> [!CAUTION]
> Reject on sight: `ServicePrincipalKey`, a service principal authenticated by a secret,
> `ARM_CLIENT_SECRET`, a full credentials JSON blob in a variable, or any client secret used to obtain
> a pipeline identity. In GitLab specifically: any unmasked CI/CD variable holding a credential.

`[TBD: the standard does not state a rotation period for the exception credentials, nor who approves
those exceptions.]`

## 6. Secrets

- Never in code.
- Use a dedicated secrets manager: Vault, or a cloud-native secrets manager.

`[TBD: the standard does not designate which is preferred, nor a rotation interval.]`

## 7. Build and artifacts

- **One build, one or more artifacts.** Build once; promote *the same artifact* through every
  environment. A pipeline that rebuilds per environment is a violation even when the source commit is
  identical.
- Unit testing is required.
- Artifacts go to the centralised artifact repository.

In GitLab: `artifacts:` with a `needs:` DAG so downstream jobs consume the upstream artifact rather
than rebuilding.

`[TBD: the standard does not name the centralised artifact repository product or location.]`

## 8. Deployment

- Approved strategies: **blue-green, canary, rolling.** Nothing else.
- **Automated rollback is required.**
- **Smoke test after every deploy.**

`[TBD: the standard does not state which strategy applies to which environment tier, nor rollback
trigger conditions, nor required smoke-test coverage.]`

## 9. Promotion

Sandbox, Dev, Test, Stage, Production. Change control tightens at each step (Minimal, Minimal,
Moderate, High, Strict). Playbooks are required for Production only.

In GitLab: `environment:` with protected environments and approval rules on the production tier.

Production and non-production workloads must never share a subscription. This is a cloud
landing-zone control that survives the CI platform change unchanged.

## Validator

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/check-pipeline.ts" <path>
```

Takes a file or a directory. Prints `LEVEL|file|line|rule|message`. Exit 0 clean, 1 errors found, 2
could not evaluate.

> [!CAUTION]
> It is a regex scanner over raw lines, not a YAML parser. It cannot follow `include:` or `extends:`,
> cannot see settings configured in the GitLab UI rather than in a file, and cannot tell whether a
> scan actually gates the pipeline or merely runs with `allow_failure: true`. **Treat a clean run as
> "nothing obvious found", never as "compliant".**

## Reference material

| File | Covers |
|---|---|
| `references/merge-request-policy.md` | Version control model, approvals, required checks, pipeline as code |
| `references/required-scans.md` | The seven scans, tools, and what is not among them |
| `references/credentials-and-secrets.md` | Federated credentials, exceptions, violation patterns, secrets |
| `references/build-and-deploy.md` | Build once and promote, artifacts, strategies, rollback, promotion tiers |
| `_SOURCES.md` | Provenance, translation notes, and the GitLab conflict |
