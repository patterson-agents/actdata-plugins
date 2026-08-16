# GitLab notes, discussions, and diff positions

The API mechanics behind inline review delivery, and why they live in a deterministic script
rather than in the agent.

## Notes vs discussions

| Object | Endpoint | Used for |
|---|---|---|
| Note | `POST/PUT /projects/:id/merge_requests/:iid/notes[/:note_id]` | The sticky summary, and the fallback for unmappable findings |
| Discussion | `POST /projects/:id/merge_requests/:iid/discussions` | One thread per finding, anchored to a diff line, resolvable |

A discussion with a `position` renders on the changed line in the diff view -- the GitHub
"inline review comment" equivalent. A plain note renders in the MR activity stream.

## Position objects

```json
{
  "body": "**[Blocker]** ...",
  "position": {
    "position_type": "text",
    "base_sha": "<diff_refs.base_sha>",
    "head_sha": "<diff_refs.head_sha>",
    "start_sha": "<diff_refs.start_sha>",
    "new_path": "src/payments/charge.ts",
    "old_path": "src/payments/charge.ts",
    "new_line": 42
  }
}
```

Rules the wrapper (`positionFor` in `post-mr-review.ts`) encodes:

- All three SHAs come from the MR's `diff_refs`, returned by
  `GET /projects/:id/merge_requests/:iid/changes`. Constructing them from other CI variables
  drifts on rebases and merged-result pipelines; use `diff_refs`.
- An **added or modified** line: `new_line` only.
- A **deleted** line: `old_line` only.
- `old_path` is required even when the file was not renamed.

## The 400 fallback is a designed path

GitLab validates the position against the actual diff and answers `400 Bad Request` when it
cannot map it -- typically a context line the MR did not change, a line index past a hunk, or a
rename edge case. Models produce such positions at a steady rate, so the wrapper treats 400 as
expected: the finding is delivered as a plain note prefixed with `path:line` instead of being
dropped. Any other non-2xx status is a real error and fails the run.

This is the core reason posting is deterministic code and not an agent tool call: the position
contract is exacting, silent partial delivery is unacceptable, and a fixture can pin the fallback
behavior in tests (`scripts/tests/mr-review/`).

## Marker-based stickiness

Every posted body ends with `<!-- code-reviews:mr-review sha=<head_sha> kind=<kind> -->`,
invisible in rendered markdown. `kind` is `summary` on the sticky note and `finding` on
discussions and fallback notes -- the distinction is load-bearing, because GitLab lists notes
newest-first and a fallback note would otherwise be mistaken for the summary and overwritten.
The wrapper identifies its own past output purely by this marker:

| Check | Action |
|---|---|
| Note with a `kind=summary` marker exists | `PUT` the summary onto it instead of posting a new one |
| That marker's SHA equals the current head | The head is already reviewed; exit without running the engine |
| Discussion with a marker, older SHA, unresolved | `PUT resolved=true`, then post fresh findings |
| No marker (a human's note or thread) | Never touched |

Fallback notes are plain notes, so unlike discussions they cannot be resolved on re-push; stale
ones stay in the activity stream, identifiable by the older SHA in their marker.

Identifying by marker rather than by author makes the behavior independent of which token or bot
user posted the earlier review.

## Token requirements

Creating notes and discussions on an MR requires a token with `api` scope acting as a member with
at least the Developer role -- a project access token stored masked as `GITLAB_TOKEN`.
`CI_JOB_TOKEN`'s permission set does not include these endpoints on self-managed or gitlab.com
instances, which is why tokenless pipelines run `log` mode. The wrapper authenticates with the
`PRIVATE-TOKEN` header.

Pagination: the wrapper reads the first 100 notes and discussions. An MR with more bot-relevant
history than that is degenerate; the marker search only needs the summary note, which stays
findable because it is updated, not re-posted.
