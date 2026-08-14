---
name: ci-auth-providers
description: This skill should be used when the user asks "which provider should we use for Claude in CI", "set up Bedrock for GitLab", "configure Workload Identity Federation", "how do I avoid storing an API key", or mentions AWS_ROLE_TO_ASSUME, assume-role-with-web-identity, GCP_WORKLOAD_IDENTITY_PROVIDER, CLAUDE_CODE_USE_BEDROCK, CLAUDE_CODE_USE_VERTEX, id_tokens, or GITLAB_OIDC_TOKEN. Covers the three provider options, their prerequisites and variables, and choosing between them.
version: 0.1.0
---

# CI authentication providers

Three ways to give a GitLab CI job access to Claude. They differ in credential handling and in what
has to be procured, not in what Claude can do.

## Choosing

| Provider | Use when |
|---|---|
| **Claude API** | Getting started, or no cloud data-residency requirement. Simplest by a wide margin. |
| **Amazon Bedrock** | AWS is the existing platform, or the spend needs to run through an AWS agreement. |
| **Google Cloud** | GCP is the existing platform, with the same procurement logic. |

The deciding factor is usually procurement and data residency, not capability. If neither constrains
you, use the Claude API and revisit later -- migrating is a job-definition change, not a rewrite.

The second factor is credential shape. Bedrock and Google Cloud both authenticate over OIDC with **no
long-lived secret stored in GitLab**, which is a genuine security improvement over a masked API key.
If your organisation's standards require federated credentials, that decides it.

## Claude API

**Setup:** add `ANTHROPIC_API_KEY` as a masked CI/CD variable. Protect it as well if the job only runs
on protected refs.

That is the whole configuration. See `examples/quick-setup.yml` in the `claude-code-ci-jobs` skill.

The tradeoff: a masked variable is a long-lived credential living in GitLab. Masking prevents it
appearing in job logs; it does not prevent a job from using it. Anyone who can run a pipeline on a
ref where the variable is available can use the key.

## Amazon Bedrock over OIDC

**Prerequisites:**

1. An AWS account with Bedrock access to the Claude models you want
2. GitLab configured as an OIDC identity provider in AWS IAM
3. An IAM role with Bedrock permissions, whose trust policy is restricted to your project and
   protected refs
4. Least-privilege permissions attached, scoped to the Bedrock invoke APIs

**Variables:** `AWS_ROLE_TO_ASSUME` (role ARN), `AWS_REGION`.

**Job variables:** `CLAUDE_CODE_USE_BEDROCK: "1"`.

GitLab mints the job's OIDC token from the `id_tokens:` block and exposes it as `GITLAB_OIDC_TOKEN`.
The job exchanges it via `aws sts assume-role-with-web-identity` for temporary credentials.

Set `aud` to the audience configured on the IAM OIDC identity provider, typically your GitLab
instance URL.

> [!IMPORTANT]
> The trust policy is the security boundary. A role trusting the GitLab OIDC provider *without*
> conditions on project and ref can be assumed from any pipeline in the instance. Restrict it to the
> specific project and to protected refs.

Bedrock model IDs carry region-specific prefixes, for example `us.anthropic.claude-sonnet-4-6`.

## Google Cloud over Workload Identity Federation

**Prerequisites:**

1. A GCP project with the Agent Platform API enabled and WIF configured to trust GitLab OIDC
2. A dedicated service account holding only the required roles
3. IAM Credentials API and STS API enabled
4. The WIF principal granted permission to impersonate the service account

**Variables:** `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT`, `GCP_PROJECT_ID`,
`CLOUD_ML_REGION`.

**Job variables:** `CLAUDE_CODE_USE_VERTEX: "1"`, `ANTHROPIC_VERTEX_PROJECT_ID`.

> [!WARNING]
> `GCP_WORKLOAD_IDENTITY_PROVIDER` is the provider resource name **without** the
> `//iam.googleapis.com/` prefix, for example
> `projects/123456789/locations/global/workloadIdentityPools/my-pool/providers/my-provider`. The
> prefix is added in the credential configuration's `audience` field. Including it in the variable
> produces a doubled prefix and an authentication failure that does not explain itself.

The flow: the job writes the OIDC token to a file, writes a credential configuration whose
`credential_source` points at that file, and sets `GOOGLE_APPLICATION_CREDENTIALS` to the
configuration. Claude Code then picks it up through Application Default Credentials.

No service account keys are downloaded or stored at any point.

## What all three share

Region selection affects latency and data residency. Choose the region nearest the runners that also
satisfies your residency requirements, and confirm the models you want are actually available there
-- model availability varies by region on both cloud providers.

## Never do this

- Commit a key, in any provider.
- Use an unmasked CI/CD variable for a credential.
- Use a downloaded GCP service account key when WIF is available.
- Grant a CI role broad permissions because scoping it was fiddly.

See the `pipeline-standards` skill for the credential rules applied to pipelines generally, and
`ci-troubleshooting` for authentication failures.
