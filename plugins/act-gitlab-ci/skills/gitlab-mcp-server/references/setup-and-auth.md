# GitLab MCP server: setup and authentication

---

## Support matrix

| Property | Value |
|---|---|
| Status | Beta since 18.6; experimental from 18.3 |
| Tiers | Free, Premium, Ultimate |
| Editions | GitLab.com, Self-Managed, Dedicated |
| MCP spec | 2025-03-26 and 2025-06-18, from 18.7 |

## Prerequisites

Three settings, all required. The scope differs by edition, which is the part that catches people
out:

| Setting | GitLab.com | Self-Managed / Dedicated |
|---|---|---|
| GitLab Duo set to "Always on" or "On by default" | Per top-level group | Instance-wide |
| Beta and experimental features enabled | Per top-level group | Instance-wide |
| MCP access allowed | Group access settings | Admin visibility and access controls |

On GitLab.com these are group-level, so enabling them for one group does not enable them for another.
A client that works for one project and not another usually means the second project's top-level
group has not been configured.

The feature flags `mcp_server` and `oauth_dynamic_client_registration` were removed in 18.6. On
current versions there is nothing to toggle at the flag level.

## Endpoint

```text
https://<gitlab.example.com>/api/v4/mcp
```

Use `gitlab.com` for GitLab.com. For Self-Managed, the instance URL.

## Transports

**HTTP** is recommended: a direct connection with no dependencies.

**stdio via `mcp-remote`** exists for clients that cannot speak HTTP. It needs Node.js 20+ and adds a
process between the client and GitLab, so prefer HTTP where the client supports it.

## Authentication

OAuth 2.0 Dynamic Client Registration. The client registers itself as an OAuth application on first
connection and receives an access token.

Each user authorises individually with their own GitLab credentials. **The server therefore acts with
the permissions of whoever authorised it.** There is no shared service identity, which means:

- A tool that works for one person may return 404 for another, because their project access differs.
- Actions taken through MCP appear in the audit log as that user.
- Revoking a person's GitLab access revokes their MCP access with it.

## Client configuration

**Claude Code (HTTP):**

```json
{
  "mcpServers": {
    "GitLab": {
      "type": "http",
      "url": "https://<gitlab.example.com>/api/v4/mcp"
    }
  }
}
```

Or:

```sh
claude mcp add --transport http GitLab https://<gitlab.example.com>/api/v4/mcp
```

**Claude Desktop (stdio):**

```json
{
  "mcpServers": {
    "GitLab": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://<gitlab.example.com>/api/v4/mcp"]
    }
  }
}
```

Other clients follow the same two shapes. Gemini uses `httpUrl` rather than `type` plus `url`; Zed
uses the stdio form with `mcp-remote@latest`.

## Tool name prefixing

Where several MCP servers expose colliding tool names:

```text
X-Gitlab-Mcp-Server-Tool-Name-Prefix: gitlab_
```

Maximum 32 characters. Worth setting whenever another connected server also offers a generic `search`
or `get_issue`.

## Rate limits

OAuth Dynamic Client Registration is limited to **10 registrations per hour per IP address**.

This matters during setup. A client retrying a failed connection can exhaust the budget, and the
subsequent failures look different from the original problem -- registration errors rather than
whatever was actually wrong. If connection attempts start failing differently after several tries,
wait rather than continuing to retry.

## Security considerations

**Prompt injection.** GitLab is explicit that guarding against it is the user's responsibility, and
that MCP tools should only be used on GitLab objects you trust. Issue descriptions, MR comments and
notes are text other people wrote.

**PKCE is not enforced by default** on pre-registered OAuth applications. Clients should send
`code_challenge` parameters.

**`clientId` is public.** It does not restrict which client software can connect, so it is an
identifier, not an access control.

**Redirect URIs.** One shared OAuth app cannot serve clients with different redirect URIs. Create
separate applications per client type.

## Feedback

Issues with the integration go to GitLab, which maintains it. See GitLab issue #561564.
