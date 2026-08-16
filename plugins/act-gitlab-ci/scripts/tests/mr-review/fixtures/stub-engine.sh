#!/bin/sh
# A fake review engine for harness tests: consumes the prompt on stdin and
# prints a findings-contract object containing one blocker.
cat >/dev/null
printf '%s\n' '{"summary":"Stub engine review.","findings":[{"path":"src/app.ts","new_line":10,"old_line":null,"severity":"blocker","title":"Stub blocker finding","body":"Emitted by the test stub."}]}'
