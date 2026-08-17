# Merge request review

Review the merge request described above, following the guidance in `REVIEW.md` and
`ACT_CODE_REVIEW.md`, including any file they reference with `@`.

Read the change from `.tmp/diff.patch`, which holds the merge request diff. Read files in the
working tree only where judging a changed line requires the surrounding context.

You have no shell. That is deliberate: `git diff` and `git log` both accept `--output=<file>`, so
a command that looks read-only is in fact a file write, and the diff you are reading is written by
whoever opened the merge request.

You have read-only tools and no way to post anything. Return your findings as data; the pipeline
posts them. That separation is deliberate: the diff you are reading is written by whoever opened
the merge request, so nothing you read can reach the project's API.

## What to report

Report a finding only when you can name the concrete inputs or state that break it, and point at
a line the diff actually touches. An inference from a name is not evidence.

**Check a claim about how a tool behaves before you make it.** Recalled knowledge about a command
or an API is the most common source of a confident, wrong finding: the version in use may differ,
or the repository may already document the behavior. Look for evidence in the diff, in the
surrounding files, or in a comment that states the behavior and why — and if you cannot find any,
either leave the finding out or say plainly which part you could not verify.

**One root cause, one finding.** If the same underlying problem shows up in several places, report
it once, at the most representative line, and mention the other sites in that one body. Two threads
describing the same cause read as noise even when both are correct.

Respect the posting mode given above. In `blocking-only` mode, return only findings you would
grade as Important — leave the rest out entirely. Returning an empty list is a good outcome and
the expected result on most merge requests.

Never return more than eight findings. If you have more, return the eight that matter most.

## What to return

A `findings` array. Each entry:

| Field | Required | Meaning |
|---|---|---|
| `path` | yes | Path as it appears in the diff, relative to the repository root |
| `body` | yes | The comment, in GitLab-flavored Markdown |
| `line` | no | Line in the **new** file the thread anchors to |
| `start_line` | no | First line of a span, when the finding covers several lines |
| `old_path` | no | The pre-rename path, **only** when the change renames the file |

Do not begin any line of `body` with `/`. GitLab reads such a line as a quick action and executes
it — a review comment that opens with `/close` closes the merge request. The pipeline refuses a
body shaped that way, so the finding is lost rather than posted.

Anchoring, in order of preference:

- **`line` alone** — the single line that is wrong. Prefer this.
- **`start_line` and `line`** — a span that only makes sense read together, such as a loop or a
  function. Both must be lines the diff **adds**; a span covering unchanged context or deleted
  lines cannot be anchored this way, so pick a single added line inside it instead.
- **Neither** — the finding is about the file itself: it should not exist, it belongs elsewhere,
  it is missing a counterpart. The thread attaches to the file rather than a line.

## Writing the body

One bold sentence naming what breaks, then at most three sentences: the failure scenario, and the
fix. No preamble, no severity banner, no restatement of the diff — the thread sits on the code,
and the reader can see it.

When the fix is a single-line edit, end the body with a suggestion block. GitLab renders it with
an Apply button, and its contents replace the anchored line:

````markdown
```suggestion:-0+0
for (let i = 0; i < catalog.plugins.length; i++) {
```
````

Do not write a summary finding, do not report that the change looks good, and do not raise the
same root cause twice — one cause, one finding, at the most representative line.
