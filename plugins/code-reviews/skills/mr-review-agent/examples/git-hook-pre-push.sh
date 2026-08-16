#!/bin/sh
# pre-push -- AI-review the commits about to be pushed.
#
# Install: copy to .git/hooks/pre-push and mark executable, or point a hook
# manager (lefthook, husky, core.hooksPath) at it. Requires codereview.sh from
# the same review bundle; adjust CODEREVIEW_SH if it lives elsewhere.
#
# Advisory by default: findings print, the push proceeds. Set
# CODEREVIEW_BLOCKING=1 to abort the push when a blocker is found. Either way,
# `git push --no-verify` skips the hook entirely.

CODEREVIEW_SH="${CODEREVIEW_SH:-.gitlab/codereview/codereview.sh}"
ZERO=0000000000000000000000000000000000000000

if [ ! -f "$CODEREVIEW_SH" ]; then
  echo "pre-push: $CODEREVIEW_SH not found; skipping AI review." >&2
  exit 0
fi

status=0
while read -r _local_ref local_sha _remote_ref remote_sha; do
  # Deleting a ref pushes nothing reviewable.
  [ "$local_sha" = "$ZERO" ] && continue

  if [ "$remote_sha" = "$ZERO" ]; then
    # New branch: review against the default branch when it exists.
    base=$(git merge-base "origin/HEAD" "$local_sha" 2>/dev/null) || base=""
  else
    base="$remote_sha"
  fi
  [ -n "$base" ] || continue

  sh "$CODEREVIEW_SH" "$base...$local_sha" || status=1
done

# Advisory unless the user opted into gating: an engine failure or a finding
# must not strand a push by default.
[ "${CODEREVIEW_BLOCKING:-0}" = "1" ] || exit 0
exit $status
