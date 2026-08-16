# GitHub Actions

Run the review in your own CI with your own credentials, using `anthropics/claude-code-action`.
Choose this over `github-managed.md` when the organization does not qualify for the managed
product, or when the trigger, model, or prompt must be under repository control.

## Install

Copy `templates/claude-code-review.yml` to `.github/workflows/claude-code-review.yml` and adapt the
trigger to the repository's conventions.

## The two lines that decide where findings go

```yaml
prompt: '/code-review:code-review --comment ${{ github.repository }}/pull/${{ github.event.pull_request.number }}'
claude_args: '--allowedTools "mcp__github_inline_comment__create_inline_comment"'
```

- **`--comment`** is what makes findings post at all. Without it the review runs and writes to the
  workflow log only. This is the correct default for a first run.
- **`claude_args`** must name the inline-comment tool even though the invoked skill's own
  frontmatter already allows it: the action starts that MCP server only when `--allowedTools` names
  it. Dropping this line produces a review that finds issues and silently posts none.

## Which review skill to invoke

Two are available and they are not interchangeable:

| Prompt | What runs |
|---|---|
| `/code-review:code-review --comment <target>` | Anthropic's upstream plugin, installed via `plugin_marketplaces` + `plugins`. Multi-agent, generate-then-validate, high-signal filter. |
| `/code-reviews:review` | This plugin's skill, which reads `REVIEW.md` and `ACT_CODE_REVIEW.md` |

Use the upstream plugin when the priority is the strongest generic bug-finding available, and this
plugin's skill when organization guidance must be applied. They can be combined by invoking the
upstream plugin and letting `CLAUDE.md` carry the ACT layer, since the upstream review reads
`CLAUDE.md` natively but does not read `REVIEW.md`.

The shipped template invokes this plugin's skill and installs no external marketplace.

## Permissions and secrets

```yaml
permissions:
  contents: read
  pull-requests: read
  issues: read
  id-token: write
```

`pull-requests: read` is sufficient: the inline-comment MCP server writes through the action's own
app token, not through `gh`. `id-token: write` is required for the action's default GitHub App
authentication.

The user creates one repository or organization secret — `ANTHROPIC_API_KEY`, or
`CLAUDE_CODE_OAUTH_TOKEN` for a subscription token, swapping the matching input. For an
organization-wide rollout prefer an API key: an OAuth token is tied to whoever generated it.

> [!CAUTION]
> On public repositories GitHub withholds secrets from fork pull requests, so the review runs only
> on same-repository branches. Do not work around this: the diff under review is untrusted input to
> a model holding the job's environment.

## Cost bounds

Keep the template's `--max-turns` and job `timeout`, and consider a concurrency group so a rapid
series of pushes cancels superseded runs. Both meters run at once — Actions minutes and API tokens.
