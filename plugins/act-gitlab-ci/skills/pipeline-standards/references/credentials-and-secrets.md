# Credentials and secrets

Derived from the Patterson CI/CD Pipeline Standards. See `../_SOURCES.md`.

The source describes "service connections", an Azure DevOps object. GitLab has no direct equivalent;
the same intent is expressed through `id_tokens:` OIDC and per-environment CI/CD variables.

---

## Credential rules

| Rule | Detail |
|---|---|
| Credential type | **Federated credentials only** |
| Exceptions | **b2c** and **vendor integration**. These two only. |
| Separation | **Different credentials per environment.** Never shared. |
| Privilege | **Least privilege.** Broad subscription-wide roles are prohibited. |
| Production | **Approval required** for a production credential |

## What federated looks like

| Platform | Shape |
|---|---|
| GitLab CI | An `id_tokens:` block minting a job OIDC token, exchanged at runtime for cloud credentials. No stored secret. |
| Azure DevOps | `authenticationScheme: WorkloadIdentityFederation` |
| GitHub Actions | `permissions: id-token: write`, with no client secret and no credentials blob |
| Terraform | `use_oidc = true` / `ARM_USE_OIDC`, never `ARM_CLIENT_SECRET` |

The GitLab form is shown working in the `ci-auth-providers` skill, for both AWS and Google Cloud.

## Violations

> [!CAUTION]
> Reject on sight:
>
> - `ServicePrincipalKey`
> - A service principal authenticated by a secret
> - `ARM_CLIENT_SECRET`
> - A full credentials JSON blob stored in a variable
> - Any client secret used to obtain a pipeline identity
>
> GitLab-specific: any **unmasked** CI/CD variable holding a credential. Masking is not encryption,
> but an unmasked credential will eventually appear in a job log.

## Masked, protected, and the difference

Two independent GitLab settings, frequently confused:

- **Masked** hides the value in job logs. It does not restrict which jobs can read it.
- **Protected** makes the variable available only on protected branches and tags.

A production credential needs both. A credential that is masked but not protected is readable by any
job on any branch, including a branch opened by anyone who can push.

This also produces a common false diagnosis: a *protected* variable is simply absent on an
unprotected branch, and the resulting failure looks like an invalid credential rather than a missing
one.

## Per-environment separation

One credential per environment, never shared. In GitLab, scope CI/CD variables to environments and
use protected environments for the production tier.

The intent is blast radius. A single credential used across environments means compromising the
development pipeline compromises production.

`[TBD: the standard does not state a rotation period for the b2c and vendor-integration exception
credentials, nor who approves those exceptions.]`

## Secrets

- **Never in code.**
- Use a **dedicated secrets manager**: Vault, or a cloud-native secrets manager.

`[TBD: the standard does not designate which is preferred, nor a secret rotation interval. A sibling
standard requires annual rotation for encryption keys, which is a different control and does not
transfer.]`

## What the validator can and cannot see

It detects the violation patterns above by regex, and it detects a cloud login with no federated
marker nearby.

It cannot check least privilege, cannot verify per-environment separation, cannot see variables
configured in the GitLab UI rather than in a file, and cannot tell a masked variable from an unmasked
one. Those need a human reading the project settings.
