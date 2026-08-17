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
# A mention counts as answered when the bot has posted anything -- a note or a
# thread -- after it. That keeps the sweep idempotent: a mention is acted on
# once, and a later mention on the same merge request is acted on again.
#
# Requires: CI_PROJECT_ID, CI_API_V4_URL, GITLAB_ACCESS_TOKEN (api scope),
# REVIEW_TRIGGER_TOKEN (a pipeline trigger token).

set -eu

BOT=${1:?usage: mention-sweep.sh <bot-username>}
: "${CI_PROJECT_ID:?not set}"
: "${CI_API_V4_URL:?not set}"
: "${REVIEW_TRIGGER_TOKEN:?not set}"

swept=0

# Open merge requests, newest first. A project with a long tail of stale merge
# requests should not make this sweep unbounded, so only the recent ones.
mrs=$(glab api "projects/${CI_PROJECT_ID}/merge_requests?state=opened&order_by=updated_at&per_page=20")
count=$(printf '%s' "$mrs" | jq 'length')

i=0
while [ "$i" -lt "$count" ]; do
  iid=$(printf '%s' "$mrs" | jq -r ".[$i].iid")
  branch=$(printf '%s' "$mrs" | jq -r ".[$i].source_branch")
  draft=$(printf '%s' "$mrs" | jq -r ".[$i].draft")
  i=$((i + 1))
  [ "$draft" = "true" ] && continue

  notes=$(glab api "projects/${CI_PROJECT_ID}/merge_requests/${iid}/notes?sort=asc&per_page=100")

  # The last mention of the bot written by someone else, and whether the bot has
  # said anything since. jq does the whole decision so the shell holds no state.
  pending=$(printf '%s' "$notes" | jq -r --arg bot "$BOT" '
    [ .[] | select(.system == false) ] as $human_and_bot
    | ( [ $human_and_bot[] | select(.author.username != $bot and (.body | contains("@" + $bot))) ] | last ) as $mention
    | if $mention == null then empty
      else
        ( [ $human_and_bot[] | select(.author.username == $bot and .created_at > $mention.created_at) ] | length ) as $answered
        | if $answered > 0 then empty else $mention.body end
      end')

  [ -z "$pending" ] && continue

  echo "sweep: !${iid} has an unanswered mention; triggering a review."
  # A pipeline started by the trigger API is not a merge request pipeline, so
  # pass the merge request explicitly; the review job reads these.
  curl -fsS -X POST \
    -F "token=${REVIEW_TRIGGER_TOKEN}" \
    -F "ref=${branch}" \
    -F "variables[REVIEW_MR_IID]=${iid}" \
    -F "variables[REVIEW_DEPTH]=all" \
    -F "variables[AI_FLOW_INPUT]=${pending}" \
    -F "variables[AI_FLOW_CONTEXT]=merge request !${iid}" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/trigger/pipeline" >/dev/null
  swept=$((swept + 1))
done

echo "sweep: triggered $swept review(s)."
