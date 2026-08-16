#!/bin/sh
# A fake review engine that reports its own environment: whether any GitLab
# token is visible (they must all be stripped or blank) and whether an
# unrelated control variable survived (it must). The summary encodes both, so
# the harness test asserts on the rendered report.
cat >/dev/null

leak="clean"
if [ -n "${GITLAB_TOKEN:-}" ] || [ -n "${GITLAB_ACCESS_TOKEN:-}" ] || [ -n "${CI_JOB_TOKEN:-}" ]; then
  leak="token-leaked"
fi

control="control-missing"
if [ "${PROBE_CONTROL:-}" = "present" ]; then
  control="control-ok"
fi

printf '{"summary":"env probe: %s %s","findings":[]}\n' "$leak" "$control"
