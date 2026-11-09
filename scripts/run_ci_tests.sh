#!/bin/sh
# Run every listed regression test and report all failures at once.
#
# The workflows used to chain `python3 <test>` lines in a single `run:` block,
# so the first failure aborted the step and every later test was silently
# skipped: one red check hid all remaining regressions. Each argument here is a
# complete command, so tests keep any arguments/interpreter they need, and the
# step fails only after the whole list is through.
set -u

[ $# -gt 0 ] || { echo "usage: $0 '<command>'..." >&2; exit 2; }

# Several tests create their scratch fixtures under artifacts/ and write logs/.
mkdir -p artifacts logs

failed=0
passed=0
summary=""

for command in "$@"; do
	log="logs/$(printf '%s' "$command" | tr -c 'A-Za-z0-9._-' '_').log"
	if sh -c "$command" >"$log" 2>&1; then
		passed=$((passed + 1))
		printf 'ok       %s\n' "$command"
	else
		status=$?
		failed=$((failed + 1))
		printf 'FAIL(%s) %s\n' "$status" "$command"
		# Keep the failure readable in the job log; full output stays in logs/.
		sed -n '1,40p' "$log"
		summary="$summary
FAIL($status) $command"
	fi
done

printf '\n%d passed, %d failed\n' "$passed" "$failed"
if [ "$failed" -ne 0 ]; then
	printf '\n=== failing tests ===%s\n' "$summary"
	exit 1
fi
