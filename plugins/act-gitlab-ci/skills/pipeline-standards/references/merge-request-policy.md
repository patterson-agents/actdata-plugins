# Version control, merge request policy, pipeline as code

Derived from the Patterson CI/CD Pipeline Standards. See `../_SOURCES.md`.

---

## Version control

| Rule | Detail |
|---|---|
| Permitted platforms | **Azure DevOps** or **GitHub** |
| Organisation model | **One organisation for all teams** |
| Team separation | With teams inside the single organisation, not separate organisations or projects |

> [!WARNING]
> **GitLab is not on the permitted list.** The source rules out anything other than Azure DevOps and
> GitHub. A GitLab pipeline is an exception to this standard, and this reference cannot say whether
> that exception has been granted. See `../_SOURCES.md`.

Translated to GitLab, the organisation model means: **one top-level group, with subgroups per team.**
Not a top-level group per team. The intent is a single administrative boundary with consistent
policy, which subgroups preserve and separate top-level groups do not.

Notes carried from the approved-software standard: GitHub is approved with no approval needed but
**enterprise managed org only**, and public repositories require approval. Azure DevOps is approved
but requires approval before use.

## Merge request policy

- **2 approvers** required. Not one. Not the author plus a bot.
- Required status checks, all five:
  1. validation pipeline
  2. container scanning
  3. SAST
  4. SCA
  5. DAST

In GitLab: a project or group approval rule setting the minimum to 2, plus required job success on
the merge request pipeline for the five checks.

The approval count is usually configured in the GitLab UI rather than in a file, which means the
validator cannot verify it. It emits a warning saying so rather than a pass.

`[TBD: the standard does not state whether the two approvers may include the author, whether code
owners are required, or whether stale-approval dismissal is mandatory.]`

## Pipeline as code

| Rule | Detail |
|---|---|
| Format | **YAML** |
| Location | **In the application repository** |
| Permitted split | The **GitOps pipeline may live in a different repository**. The only allowed split. |
| Templates | **Standardised templates** must be used |

In GitLab, standardised templates means `include:` from a central template project, or components
from the CI/CD component catalogue.

`[TBD: the standard does not name the location, version or contents of the standardised templates.]`

> [!NOTE]
> The validator cannot follow `include:` or `extends:`. A scan defined in an included template reads
> as missing. This is the single largest source of false positives when a repository uses templates
> properly, which the standard requires it to do.

## Review cadence

`[TBD: no review cadence is stated for the CI/CD Pipeline Standards. A sibling standard states an
annual cadence for itself; do not assume the same applies here.]`
