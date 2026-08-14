# Required CI scans

Derived from the Patterson CI/CD Pipeline Standards. See `../_SOURCES.md`.

---

## The seven

CI must include all of the following.

| # | Scan | Named tool | Approval | Owner |
|---|---|---|---|---|
| 1 | SAST | Checkmarx | Required | AppSec |
| 2 | SCA | Checkmarx | Required | AppSec |
| 3 | DAST | `[TBD: no tool named]` | `[TBD]` | `[TBD]` |
| 4 | Secret scanning | GitLeaks | None needed | AppSec |
| 5 | API scanning | Checkmarx | Required | AppSec |
| 6 | Container scanning | **Trivy or Checkmarx** | Trivy: none. Checkmarx: required | AppSec |
| 7 | IaC scanning | Checkmarx | Required | AppSec |

Four of the seven are Checkmarx, and Checkmarx requires approval. A team standing up a compliant
pipeline therefore needs that approval before it can satisfy most of this section, and has no named
tool at all for DAST.

## GitLab's built-in scanners are not approved

> [!IMPORTANT]
> GitLab ships SAST, Dependency Scanning, Secret Detection and Container Scanning as platform
> features. **None appears on the approved-tools list.** Under the source standard's own rule, a tool
> that is not listed requires review before use.

The practical consequence: a GitLab pipeline aiming at compliance turns off the native scanners it
would otherwise get for free, and integrates Checkmarx, GitLeaks and Trivy instead. That is a real
cost, and it is invisible until someone compares the tool list against the platform's defaults.

Whether GitLab's scanners should be added to the approved list is a decision for the standard's
owner. It is not something this reference can resolve.

## Approved base images

Only security-approved images may be used.

`[TBD: the standards do not enumerate an approved container base image or registry list. The
approved-image rule as written refers to virtual machine images.]`

## Not among the seven

Two tools are easy to mistake for satisfying a requirement here:

- **JFrog** covers third-party package security. Approval required. It is not one of the seven CI
  scans.
- **Qualys** is vulnerability scanning, running on its own schedule. Approval required. Also not one
  of the seven.

Neither satisfies an SCA or container-scanning requirement.

## Substitutions that are not accepted

The source standard names specific tools. These common alternatives do **not** satisfy the
requirement:

| Instead of | Required |
|---|---|
| Snyk, Dependabot-as-SCA, OWASP Dependency-Check | Checkmarx |
| SonarQube, Semgrep, CodeQL | Checkmarx |
| Grype, Clair, Anchore | Trivy or Checkmarx |
| TruffleHog, detect-secrets | GitLeaks |
| Checkov, tfsec, Terrascan | Checkmarx |

## Trivy's status

The approved-software standard records that Checkmarx will replace Trivy. Trivy remains approved
today; new work should account for the migration rather than building deeply around it.

## Enforcement and its limits

`${CLAUDE_PLUGIN_ROOT}/scripts/check-pipeline.ts` detects each scan by keyword.

> [!CAUTION]
> Keyword detection proves a **string is present**, not that the scan runs, gates the build, or is
> configured correctly. A job with `allow_failure: true` passes the keyword check while failing to
> gate anything. Confirm gating by reading the pipeline.
