#!/bin/sh
# Post one review thread on the merge request this job is running for.
#
# Usage: post-review-thread.sh <payload.json>
#
# The reviewer reads the merge request diff, which is untrusted input: anything
# a contributor can write into a file can reach the model's context. Granting
# the reviewer a general `glab api` command would therefore hand that input a
# project access token with the api scope and every endpoint and method it
# reaches. This wrapper is the whole of the reviewer's write access instead --
# one endpoint, one method, one merge request, taken from the job environment
# rather than from anything the model can choose.

set -eu

PAYLOAD=${1:?usage: post-review-thread.sh <payload.json>}

: "${CI_PROJECT_ID:?not set}"
: "${CI_MERGE_REQUEST_IID:?not set}"

# Refuse a payload outside the job's scratch directory, so a crafted path
# cannot make this read something else and post it.
case "$PAYLOAD" in
  .tmp/*) ;;
  *) echo "post-review-thread: payload must live under .tmp/" >&2; exit 2 ;;
esac
[ -f "$PAYLOAD" ] || { echo "post-review-thread: no such payload: $PAYLOAD" >&2; exit 2; }

exec glab api \
  "projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/discussions" \
  -X POST --input "$PAYLOAD"
