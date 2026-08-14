# Zoho Projects API reference

Field-tested quirks of the Zoho Projects REST API. These are the things that cost an afternoon the
first time.

All portal, project and user IDs come from `.claude/act-work-tracking.local.md`. None are recorded
here.

---

## Authentication

| Property | Value |
|---|---|
| Token type | Opaque bearer. Not a JWT, not parseable. |
| Header | `Authorization: Zoho-oauthtoken {access_token}` |
| Access token lifetime | 1 hour |
| Refresh token lifetime | Indefinite until revoked |

> [!IMPORTANT]
> The header prefix is `Zoho-oauthtoken`, **not** `Bearer`. This is the single most common mistake
> against this API, and the failure mode is an unhelpful 401 that looks like an expired token.

### Self Client flow

The simplest path for a script or a service integration. Generate a grant code in the browser at
`https://api-console.zoho.com`, then exchange it for a refresh and access token pair with one
request. No web server, no redirect URI handling.

The grant code is short-lived, so exchange it promptly. The refresh token that comes back is the
durable credential -- store it as a secret, not in a config file.

## API domains

| Service | Domain |
|---|---|
| Accounts | `https://accounts.zoho.com` |
| Projects | `https://projectsapi.zoho.com` |

Regional data centres use different top-level domains (`.eu`, `.in`, `.com.au`, and others). A token
issued in one region does not work against another, and the resulting error does not say so. If
authentication succeeds but every resource returns 404, check the region first.

## Resource naming

**Tasks** are the high-level abstract items.

**Issues** are exposed through the **bugs API**. The URL path contains `/bugs/` and the response keys
use `bugs[]`, regardless of what the web interface calls them. Teams that say "issue" in conversation
still call `/bugs/` in code.

## Endpoints (V1 path style)

| Action | Method | Path |
|---|---|---|
| Get refresh and access tokens | POST | `{accounts}/oauth/v2/token` |
| List projects | GET | `{api}/restapi/portal/{portal_id}/projects/` |
| Create task | POST | `{api}/restapi/portal/{portal_id}/projects/{project_id}/tasks/` |
| Create issue | POST | `{api}/restapi/portal/{portal_id}/projects/{project_id}/bugs/` |

### V3 path style

The newer V3 API uses `/api/v3/portal/{portal_id}/...`. Some MCP servers use V3 while scripts use V1.
Mixing the two produces confusing 404s, so establish which style a given tool speaks before
debugging further.

## Required fields

**Tasks:** `name` (the title), `description`, `priority` (one of `None`, `Low`, `Medium`, `High`).

**Issues:** `title`, `description`.

Descriptions accept HTML. Use `<br>` for line breaks; a literal newline in the payload does not
render.

> [!WARNING]
> Do **not** send the `flag` field when creating an issue. It causes the request to fail, and the
> error does not identify the offending field.

## Response parsing

Task creation returns:

```json
{ "tasks": [ { "id_string": "...", "key": "PREFIX-42" } ] }
```

Issue creation returns:

```json
{ "bugs": [ { "id_string": "...", "key": "PREFIX-43" } ] }
```

Two identifiers, and they are not interchangeable:

- `key` is the human-facing reference, like `PREFIX-42`. Use it in conversation and in commit
  messages.
- `id_string` is what subsequent API calls need.

Note the response key differs between the two resources: `tasks[]` versus `bugs[]`. Code that
handles both needs to branch on the resource type.

## Rate limits

100 requests per 2 minutes. Sleep 1.5 to 2 seconds between calls to stay well clear -- a bulk import
of a few dozen items will otherwise hit the ceiling partway through, leaving a half-created backlog
that has to be reconciled by hand.

## Discovering project IDs

Retrieve them through the projects list endpoint with a large page size (200) to avoid pagination.
Record the results in the settings file rather than looking them up on every run.

## MCP tool names

Where a Zoho MCP server is configured, use exact namespaced tool names for reliable resolution
rather than relying on fuzzy matching:

- `ZohoProjects_get_projects_list`
- `ZohoProjects_create_a_task`
- `ZohoProjects_create_issue`

The namespace prefix depends on how the server is registered in the client.
