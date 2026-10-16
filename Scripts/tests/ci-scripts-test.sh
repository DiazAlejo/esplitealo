#!/usr/bin/env bash
# Tests for Scripts/ci-logs.sh, Scripts/xcresult-summary.sh and Scripts/ci-xcodebuild.sh, using stub gh, xcrun and
# xcodebuild programs so no network, simulator or Xcode is needed.
#
# Usage: Scripts/tests/ci-scripts-test.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"

failures=0
check() { # check <description> <condition exit status>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi
}
contains() { grep -qF -- "$2" <<<"$1"; }

# --- stub gh ----------------------------------------------------------------------------------------------------
cat > "$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB_LOG"
case "$1 $2" in
  "run list") [ -z "${STUB_RUN:-}" ] || printf '%s\n' "$STUB_RUN" ;;
  "run view")
    case "$*" in
      *--log-failed*) seq 1 "${STUB_LOG_LINES:-1000}" | sed 's/^/failed log line /' ;;
      *"--json jobs"*) printf '  failure\tiOS App\n  success\tmacOS\n' ;;
      *"--json status,conclusion"*) printf 'completed\t%s\n' "${STUB_FINAL_CONCLUSION:-success}" ;;
    esac ;;
  "run watch") echo "watched" ;;
esac
STUB
chmod +x "$work/bin/gh"

# A git repository on branch "feature" to run ci-logs.sh in.
repo="$work/repo"
git init -q -b feature "$repo"
git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
head_sha="$(git -C "$repo" rev-parse HEAD)"
export STUB_LOG="$work/gh.log"
logs() { (cd "$repo" && PATH="$work/bin:$PATH" "$root/Scripts/ci-logs.sh" "$@" 2>&1); }

tab=$'\t'
export STUB_RUN="42${tab}completed${tab}failure${tab}${head_sha}${tab}https://example.test/runs/42${tab}my change"
out="$(logs)"; code=$?
check "failed run: exits 1" "$([ $code -eq 1 ] && echo 0 || echo 1)"
check "failed run: uses the current branch" "$(grep -q -- '--branch feature' "$STUB_LOG" && echo 0 || echo 1)"
check "failed run: lists the jobs" "$(contains "$out" 'failure	iOS App' && echo 0 || echo 1)"
check "failed run: prints the failed log" "$(contains "$out" 'failed log line 1000' && echo 0 || echo 1)"
check "failed run: tails 300 lines by default" "$(contains "$out" 'failed log line 701' && ! contains "$out" 'failed log line 700' && echo 0 || echo 1)"

out="$(logs --lines 0)"
check "--lines 0 prints everything" "$(contains "$out" 'failed log line 1 ' || contains "$out" 'failed log line 1'$'\n' && echo 0 || echo 1)"

out="$(logs --branch other --repo me/app --workflow Build -n 5)"
check "options are passed to gh" "$(grep -q -- 'run list -R me/app --branch other --workflow Build' "$STUB_LOG" && echo 0 || echo 1)"
check "--lines 5 tails 5 lines" "$(contains "$out" 'failed log line 996' && ! contains "$out" 'failed log line 995' && echo 0 || echo 1)"

export STUB_RUN="43${tab}completed${tab}success${tab}${head_sha}${tab}https://example.test/runs/43${tab}ok"
out="$(logs)"; code=$?
check "passed run: exits 0" "$([ $code -eq 0 ] && echo 0 || echo 1)"
check "passed run: prints no failed logs" "$(! contains "$out" 'failed log line' && echo 0 || echo 1)"

export STUB_RUN="44${tab}completed${tab}failure${tab}0000000000000000000000000000000000000000${tab}https://example.test/runs/44${tab}old"
out="$(logs)"
check "stale run: warns that HEAD differs" "$(contains "$out" 'not your HEAD' && echo 0 || echo 1)"

export STUB_RUN="45${tab}in_progress${tab}${tab}${head_sha}${tab}https://example.test/runs/45${tab}busy"
out="$(logs)"; code=$?
check "unfinished run: exits 2" "$([ $code -eq 2 ] && echo 0 || echo 1)"
export STUB_FINAL_CONCLUSION=success
out="$(logs --wait)"; code=$?
check "--wait watches, then reports the result" "$([ $code -eq 0 ] && grep -q 'run watch' "$STUB_LOG" && echo 0 || echo 1)"

export STUB_RUN=""
out="$(logs)"; code=$?
check "no run: exits 2 with a hint" "$([ $code -eq 2 ] && contains "$out" 'No "CI" run found for branch feature' && echo 0 || echo 1)"

out="$(logs --bogus)"; code=$?
check "unknown option: exits 3" "$([ $code -eq 3 ] && echo 0 || echo 1)"
out="$(logs --lines many)"; code=$?
check "non-numeric --lines: exits 3" "$([ $code -eq 3 ] && echo 0 || echo 1)"

# --- stub xcrun and xcodebuild ------------------------------------------------------------------------------------
cat > "$work/bin/xcrun" <<'STUB'
#!/usr/bin/env bash
# xcrun xcresulttool get test-results summary --path <bundle> --compact
cat "$STUB_SUMMARY_JSON"
STUB
cat > "$work/bin/xcodebuild" <<'STUB'
#!/usr/bin/env bash
echo "xcodebuild $*" >> "$STUB_LOG"
while [ $# -gt 0 ]; do
  [ "$1" = "-resultBundlePath" ] && { mkdir -p "$2"; ls "$2" > "$STUB_BUNDLE_CONTENT"; touch "$2/new"; }
  shift
done
exit "${STUB_XCODEBUILD_STATUS:-0}"
STUB
chmod +x "$work/bin/xcrun" "$work/bin/xcodebuild"

fixtures="$root/Scripts/tests/fixtures"
mkdir -p "$work/Failed.xcresult" "$work/Passed.xcresult"

export STUB_SUMMARY_JSON="$fixtures/failed-summary.json"
export GITHUB_STEP_SUMMARY="$work/step-summary.md"
out="$(PATH="$work/bin:$PATH" "$root/Scripts/xcresult-summary.sh" "$work/Failed.xcresult" 2>&1)"; code=$?
check "summary: exits 0 even for a failed run" "$([ $code -eq 0 ] && echo 0 || echo 1)"
check "summary: shows the counts" "$(contains "$out" 'Result: Failed  (passed 53, failed 2' && echo 0 || echo 1)"
check "summary: shows the device" "$(contains "$out" 'Device: iPhone 16 (iOS Simulator 18.6)' && echo 0 || echo 1)"
check "summary: names the failed UI test and its message" "$(contains "$out" '- SmokeTests/testLaunchesToHome() [EsplitealoUITests]' && contains "$out" 'Failed to find element "home.scan"' && echo 0 || echo 1)"
check "summary: shows every line of a message" "$(contains "$out" 'Second line of context' && echo 0 || echo 1)"
check "summary: names the failed snapshot test" "$(contains "$out" '- HomeSnapshotTests/homeScreen() [EsplitealoTests]' && echo 0 || echo 1)"
check "summary: writes the GitHub step summary" "$(grep -q 'Snapshot does not match reference' "$GITHUB_STEP_SUMMARY" && grep -q '^### Test results: Failed' "$GITHUB_STEP_SUMMARY" && echo 0 || echo 1)"

export STUB_SUMMARY_JSON="$fixtures/passed-summary.json"
out="$(PATH="$work/bin:$PATH" "$root/Scripts/xcresult-summary.sh" "$work/Passed.xcresult" 2>&1)"
check "summary: a passed run lists no failures" "$(contains "$out" 'Result: Passed  (passed 55' && ! contains "$out" 'Failed tests' && echo 0 || echo 1)"

out="$(PATH="$work/bin:$PATH" "$root/Scripts/xcresult-summary.sh" "$work/missing.xcresult" 2>&1)"; code=$?
check "summary: a missing bundle is explained, exit 0" "$([ $code -eq 0 ] && contains "$out" 'no result bundle' && echo 0 || echo 1)"

# --- ci-xcodebuild.sh ---------------------------------------------------------------------------------------------
export STUB_SUMMARY_JSON="$fixtures/failed-summary.json"
export STUB_BUNDLE_CONTENT="$work/bundle-content"
export CI_RESULTS_DIR="$work/results"
mkdir -p "$CI_RESULTS_DIR/ui.xcresult" && touch "$CI_RESULTS_DIR/ui.xcresult/stale"
: > "$STUB_LOG"
out="$(STUB_XCODEBUILD_STATUS=65 PATH="$work/bin:$PATH" "$root/Scripts/ci-xcodebuild.sh" ui test -scheme App 2>&1)"; code=$?
check "wrapper: keeps xcodebuild's exit status" "$([ $code -eq 65 ] && echo 0 || echo 1)"
check "wrapper: passes the arguments and a result bundle path" "$(grep -q "xcodebuild test -scheme App -resultBundlePath $work/results/ui.xcresult" "$STUB_LOG" && echo 0 || echo 1)"
check "wrapper: removes a stale bundle first" "$([ ! -s "$STUB_BUNDLE_CONTENT" ] && echo 0 || echo 1)"
check "wrapper: prints the summary after xcodebuild" "$(contains "$out" '== Test result summary (ui.xcresult)' && echo 0 || echo 1)"
out="$(PATH="$work/bin:$PATH" "$root/Scripts/ci-xcodebuild.sh" ui test 2>&1)"; code=$?
check "wrapper: success exits 0" "$([ $code -eq 0 ] && echo 0 || echo 1)"

echo
if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
