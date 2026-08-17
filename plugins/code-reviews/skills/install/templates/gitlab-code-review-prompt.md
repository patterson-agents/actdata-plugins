# Merge request review

Review the merge request described above, following the guidance in `REVIEW.md` and
`ACT_CODE_REVIEW.md`, including any file they reference with `@`.

Read the change with `git diff <base_sha>...<head_sha>` using the diff refs given above.
Read surrounding context only where judging a changed line requires it.

## What to report

Report a finding only when you can name the concrete inputs or state that break it and cite
`path:line` from the diff. An inference from a name is not evidence.

Respect the posting mode given above. In `blocking-only` mode, post nothing that you would
grade below Important: print those to stdout for the job log instead. Silence is a good
outcome, and a review that posts nothing is the expected result on most merge requests.

## How to post

Every finding is an inline discussion anchored to the line it concerns, so it renders in the
Changes tab as a resolvable thread instead of a comment in the activity feed.

For each finding:

1. Write the note body to `.tmp/body.md`. Keep it to a single bold sentence naming what
   breaks, then at most three sentences: the failure scenario, and the fix. No preamble, no
   restatement of the diff, no severity banner — the thread's position already says where it
   is, and the reader can see the code beside it.

2. When the fix is a single-line edit, end the body with a suggestion block so the author can
   apply it from the UI in one click. The line inside it replaces the line the thread is
   anchored to:

   ```suggestion:-0+0
   for (let i = 0; i < catalog.plugins.length; i++) {
   ```

3. Anchor the thread. Pick the narrowest anchor that contains the problem — a reader should not
   have to hunt for which line you mean.

   **One line.** `new_line` is the line number in the *new* file:

   ```sh
   jq -n --rawfile body .tmp/body.md \
         --arg path '<path from the diff>' \
         --argjson line <line in the new file> \
         --argjson refs "$DIFF_REFS" \
         '{body: $body, position: ($refs + {position_type: "text",
                                            old_path: $path, new_path: $path,
                                            new_line: $line})}' \
     > .tmp/note.json
   ```

   **A span of lines** — a loop, a function, a block that only makes sense read together. Add a
   `line_range`, whose `line_code` is the SHA-1 of the file path, then the old and new line
   numbers, with `0` standing in for a line that does not exist on that side:

   ```sh
   CODE=$(printf '%s' '<path>' | sha1sum | cut -d' ' -f1)
   jq -n --rawfile body .tmp/body.md \
         --arg path '<path>' --arg code "$CODE" \
         --argjson first <first line> --argjson last <last line> \
         --argjson refs "$DIFF_REFS" \
         '{body: $body, position: ($refs + {position_type: "text",
             old_path: $path, new_path: $path, new_line: $last,
             line_range: {
               start: {line_code: "\($code)_0_\($first)", type: "new", old_line: null, new_line: $first},
               end:   {line_code: "\($code)_0_\($last)",  type: "new", old_line: null, new_line: $last}}})}' \
     > .tmp/note.json
   ```

   **A whole file** — for something about the file itself (it should not exist, it belongs
   elsewhere, it is missing a counterpart) rather than any line in it:

   ```sh
   jq -n --rawfile body .tmp/body.md --arg path '<path>' --argjson refs "$DIFF_REFS" \
         '{body: $body, position: ($refs + {position_type: "file", old_path: $path, new_path: $path})}' \
     > .tmp/note.json
   ```

   Then post whichever payload you built:

   ```sh
   .gitlab/post-review-thread.sh .tmp/note.json
   ```

   A 400 from that call almost always means the line is not one the diff actually adds or keeps.
   Re-read the hunk header and use a line the diff touches, rather than retrying blindly. For a
   line the change *deletes*, set `old_line` instead of `new_line` and use `type: "old"`.

## What not to do

- Do not post a summary note. The discussion count and the pipeline status already say the
  review ran, and a summary duplicates findings the reader can see in place.
- Do not post a note saying the change looks good, and do not open a thread to say a concern
  turned out to be fine.
- Do not repeat a finding in more than one thread. One root cause, one thread, at the most
  representative line.
- Do not modify tracked files. Scratch belongs in `.tmp/`.
