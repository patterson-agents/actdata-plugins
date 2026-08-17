#!/bin/sh
# Answer @mentions of the review bot on open merge requests.
#
# Usage: mention-sweep.sh <bot-username>
#
# GitLab does not run a pipeline when someone comments, and the official
# integration's mention-driven path needs an event listener you host yourself.
# This is the same behavior without a service: a scheduled pipeline asks which
# open merge requests have an unanswered mention, and triggers a review pipeline
# for each, passing the comment through as AI_FLOW_INPUT.
#
# Idempotency is the whole difficulty. "Has the bot replied since?" is the
# obvious test and the wrong one: a clean review posts nothing by design, so the
# mention would stay unanswered and every sweep would pay for the same review
# again, forever. Instead the bot awards an emoji to the mention itself the
# moment a review is triggered. That records the fact independently of whether
# the review had anything to say, and it shows up in the UI as an
# acknowledgement rather than as another comment.
#
# Requires: CI_PROJECT_ID, CI_API_V4_URL, GITLAB_ACCESS_TOKEN (api scope),
# REVIEW_TRIGGER_TOKEN (a pipeline trigger token).

set -eu

BOT=${1:?usage: mention-sweep.sh <bot-username>}
: "${CI_PROJECT_ID:?not set}"
: "${CI_API_V4_URL:?not set}"
: "${REVIEW_TRIGGER_TOKEN:?not set}"

# The emoji that marks a mention as already acted on. Any name GitLab accepts
# works; "eyes" reads as "seen" to a person looking at the thread.
SEEN_EMOJI="eyes"

swept=0
skipped=0

# Open merge requests, most recently updated first. A project with a long tail
# of stale merge requests should not make this sweep unbounded.
mrs=$(glab api "projects/${CI_PROJECT_ID}/merge_requests?state=opened&order_by=updated_at&per_page=20")
count=$(printf '%s' "$mrs" | jq 'length')

i=0
while [ "$i" -lt "$count" ]; do
  iid=$(printf '%s' "$mrs" | jq -r ".[$i].iid")
  branch=$(printf '%s' "$mrs" | jq -r ".[$i].source_branch")
  draft=$(printf '%s' "$mrs" | jq -r ".[$i].draft")
  i=$((i + 1))
  [ "$draft" = "true" ] && continue

  # --paginate, because a busy merge request has more than one page of notes
  # and the mention may be on any of them. It emits one array per page, so
  # slurp and concatenate before asking anything of the result.
  notes=$(glab api --paginate "projects/${CI_PROJECT_ID}/merge_requests/${iid}/notes?sort=asc&per_page=100" \
          | jq -s 'add // []')

  # The most recent mention of the bot written by somebody else.
  mention=$(printf '%s' "$notes" | jq -c --arg bot "$BOT" '
    [ .[]
      | select(.system == false)
      | select(.author.username != $bot)
      | select(.body | contains("@" + $bot))
    ] | last // empty')

  [ -z "$mention" ] && continue

  note_id=$(printf '%s' "$mention" | jq -r '.id')
  body=$(printf '%s' "$mention" | jq -r '.body')

  # Already acted on? The award is the record, not the presence of a reply.
  awarded=$(glab api "projects/${CI_PROJECT_ID}/merge_requests/${iid}/notes/${note_id}/award_emoji" \
            | jq --arg bot "$BOT" --arg e "$SEEN_EMOJI" \
                 '[ .[] | select(.user.username == $bot and .name == $e) ] | length')
  if [ "$awarded" -gt 0 ]; then
    skipped=$((skipped + 1))
    continue
  fi

  echo "sweep: !${iid} note ${note_id} has an unanswered mention; triggering a review."

  # Mark it before triggering. Marking afterwards would loop forever if the
  # trigger call fails halfway; marking first can at worst miss one mention,
  # which a person can repeat, and cannot spend money in a loop.
  glab api "projects/${CI_PROJECT_ID}/merge_requests/${iid}/notes/${note_id}/award_emoji" \
    -X POST -f "name=${SEEN_EMOJI}" >/dev/null

  # A pipeline started by the trigger API is not a merge request pipeline, so
  # pass the merge request explicitly; the review job reads these.
  #
  # --form-string, not -F: curl reads a value beginning with @ as a filename,
  # and a mention comment begins with the bot's @name by definition. With -F
  # this both fails on ordinary use and turns a comment into a file read.
  curl -fsS -X POST \
    --form-string "token=${REVIEW_TRIGGER_TOKEN}" \
    --form-string "ref=${branch}" \
    --form-string "variables[REVIEW_MR_IID]=${iid}" \
    --form-string "variables[REVIEW_DEPTH]=all" \
    --form-string "variables[AI_FLOW_INPUT]=${body}" \
    --form-string "variables[AI_FLOW_CONTEXT]=merge request !${iid}" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/trigger/pipeline" >/dev/null

  swept=$((swept + 1))
done

echo "sweep: triggered $swept review(s), skipped $skipped already acknowledged."
