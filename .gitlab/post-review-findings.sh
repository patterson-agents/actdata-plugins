#!/bin/sh
# Post reviewer findings as inline discussions on the merge request in scope.
#
# Usage: post-review-findings.sh <findings.json> <diff-refs.json>
#
# The reviewer runs with read-only tools and returns findings as data. This
# script, not the model, holds the credential and decides what is posted and
# where: the project and merge request come from the job environment, and the
# only field taken from the model is the comment body plus a path and line it
# has to justify. Handing the model a posting command instead would put the
# project access token one prompt injection away from the untrusted diff it
# reads -- including, if it could write files, by rewriting the posting command.
#
# findings.json: {"findings": [{path, body, line?, start_line?}, ...]}

set -eu

FINDINGS=${1:?usage: post-review-findings.sh <findings.json> <diff-refs.json>}
DIFF_REFS_FILE=${2:?usage: post-review-findings.sh <findings.json> <diff-refs.json>}

: "${CI_PROJECT_ID:?not set}"
: "${CI_MERGE_REQUEST_IID:?not set}"

ENDPOINT="projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/discussions"
WORK=$(dirname -- "$FINDINGS")
posted=0
failed=0

count=$(jq '.findings | length' "$FINDINGS")
if [ "$count" -eq 0 ]; then
  echo "review: no findings to post."
  exit 0
fi

i=0
while [ "$i" -lt "$count" ]; do
  finding=$(jq -c ".findings[$i]" "$FINDINGS")
  i=$((i + 1))

  path=$(printf '%s' "$finding" | jq -r '.path')
  line=$(printf '%s' "$finding" | jq -r '.line // empty')
  start=$(printf '%s' "$finding" | jq -r '.start_line // empty')

  # line_code is the SHA-1 of the file path, then the old and new line numbers,
  # with 0 for a side the line does not exist on.
  code=$(printf '%s' "$path" | sha1sum | cut -d' ' -f1)

  if [ -z "$line" ]; then
    # No line: anchor the thread to the file itself.
    printf '%s' "$finding" | jq \
      --slurpfile refs "$DIFF_REFS_FILE" --arg path "$path" \
      '{body: .body,
        position: ($refs[0] + {position_type: "file", old_path: $path, new_path: $path})}' \
      > "$WORK/payload.json"
  elif [ -n "$start" ] && [ "$start" != "$line" ]; then
    # A span. Both ends must be lines the diff adds; see the reviewer prompt.
    printf '%s' "$finding" | jq \
      --slurpfile refs "$DIFF_REFS_FILE" --arg path "$path" --arg code "$code" \
      --argjson first "$start" --argjson last "$line" \
      '{body: .body,
        position: ($refs[0] + {position_type: "text", old_path: $path, new_path: $path,
          new_line: $last,
          line_range: {
            start: {line_code: "\($code)_0_\($first)", type: "new", old_line: null, new_line: $first},
            end:   {line_code: "\($code)_0_\($last)",  type: "new", old_line: null, new_line: $last}}})}' \
      > "$WORK/payload.json"
  else
    printf '%s' "$finding" | jq \
      --slurpfile refs "$DIFF_REFS_FILE" --arg path "$path" --argjson line "$line" \
      '{body: .body,
        position: ($refs[0] + {position_type: "text", old_path: $path, new_path: $path,
                               new_line: $line})}' \
      > "$WORK/payload.json"
  fi

  if glab api "$ENDPOINT" -X POST --input "$WORK/payload.json" >/dev/null 2>"$WORK/err.txt"; then
    posted=$((posted + 1))
    echo "review: posted a thread on ${path}${line:+:$line}"
  else
    failed=$((failed + 1))
    # A 400 here is nearly always a line the diff does not touch. Report the
    # finding in the log rather than losing it, and keep going.
    echo "review: could not anchor a thread on ${path}${line:+:$line}:" >&2
    sed 's/^/  /' "$WORK/err.txt" >&2
    printf '%s' "$finding" | jq -r '"  --- finding ---\n" + .body' >&2
  fi
done

echo "review: posted $posted thread(s), $failed could not be anchored."
