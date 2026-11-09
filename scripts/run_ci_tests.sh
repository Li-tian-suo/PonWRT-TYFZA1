#!/bin/sh
# Run every listed regression test and report all failures at once.
#
# The workflow used to chain `python3 <test>` lines in a single `run:` block,
# so the first failure aborted the step and every later test was silently
# skipped: one red check hid all remaining regressions. Keep the list here,
# run each test in isolation, and fail only after the whole list is through.
set -u

[ $# -gt 0 ] || { echo "usage: $0 <test.py>..." >&2; exit 2; }

# Several tests create their scratch fixtures under artifacts/ and write logs/.
mkdir -p artifacts logs

failed=0
passed=0
skipped=0
summary=""

for test in "$@"; do
	if [ ! -f "$test" ]; then
		printf 'MISSING  %s\n' "$test"
		failed=$((failed + 1))
		summary="$summary
MISSING  $test (listed in the workflow but not in the tree)"
		continue
	fi
	log="logs/$(printf '%s' "$test" | tr '/' '_').log"
	if python3 "$test" >"$log" 2>&1; then
		passed=$((passed + 1))
		printf 'ok       %s\n' "$test"
	else
		status=$?
		failed=$((failed + 1))
		printf 'FAIL(%s) %s\n' "$status" "$test"
		# Keep the failure readable in the job log; full output stays in logs/.
		sed -n '1,40p' "$log"
		summary="$summary
FAIL($status) $test"
	fi
done

printf '\n%d passed, %d failed\n' "$passed" "$failed"
if [ "$failed" -ne 0 ]; then
	printf '\n=== failing tests ===%s\n' "$summary"
	exit 1
fi
