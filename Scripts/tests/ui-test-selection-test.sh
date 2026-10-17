#!/usr/bin/env bash
# Tests for Scripts/ui-test-selection.sh against a temporary Journeys folder, and against the real one: every journey
# class must be in exactly one shard and skipped by the app selection.
#
# Usage: Scripts/tests/ui-test-selection-test.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/Scripts/ui-test-selection.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
check() { if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi; }

mkdir -p "$work/J"
printf 'import XCTest\nfinal class BUITests: JourneyTestCase {\n}\n' > "$work/J/B.swift"
printf 'final class AUITests: JourneyTestCase {}\n' > "$work/J/A.swift"
printf 'final class DUITests: XCTestCase {}\nfinal class CUITests: XCTestCase {}\n' > "$work/J/D.swift"
printf 'class JourneyTestCase: XCTestCase {}\n' > "$work/J/Base.swift"
export UI_TEST_JOURNEYS_DIR="$work/J"

expected_app=$'-only-testing:EsplitealoUITests\n-skip-testing:EsplitealoUITests/AUITests\n-skip-testing:EsplitealoUITests/BUITests\n-skip-testing:EsplitealoUITests/CUITests\n-skip-testing:EsplitealoUITests/DUITests'
[ "$("$script" app)" = "$expected_app" ]; check "app selects everything and skips each journey class" $?

[ "$("$script" journeys 1 3)" = $'-only-testing:EsplitealoUITests/AUITests\n-only-testing:EsplitealoUITests/DUITests' ]; check "shard 1/3 is round-robin over the sorted classes" $?
[ "$("$script" journeys 2 3)" = "-only-testing:EsplitealoUITests/BUITests" ]; check "shard 2/3" $?
[ "$("$script" journeys 3 3)" = "-only-testing:EsplitealoUITests/CUITests" ]; check "shard 3/3" $?
[ -z "$("$script" journeys 5 5)" ]; check "a shard past the class count is empty" $?
"$script" journeys 4 3 >/dev/null 2>&1; [ $? -eq 2 ]; check "a shard outside 1..total is rejected" $?
"$script" journeys x 3 >/dev/null 2>&1; [ $? -eq 2 ]; check "a non-numeric shard is rejected" $?
"$script" bogus >/dev/null 2>&1; [ $? -eq 2 ]; check "an unknown mode is rejected" $?

# The real folder: the shards partition the classes, and the app selection skips exactly those.
unset UI_TEST_JOURNEYS_DIR
all="$( (for s in 1 2 3; do "$script" journeys $s 3; done) | sed 's/^-only-testing://' | sort)"
skipped="$("$script" app | sed -n 's/^-skip-testing://p' | sort)"
[ -n "$all" ] && [ "$all" = "$skipped" ]; check "real folder: shards and skips list the same classes" $?
[ "$(sort -u <<<"$all" | wc -l)" -eq "$(wc -l <<<"$all")" ]; check "real folder: no class is in two shards" $?

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
echo "all passed"
