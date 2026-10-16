#!/usr/bin/env bash
# Run xcodebuild the way CI does: write a result bundle, print a failure summary into the same log, and exit with
# xcodebuild's own status. The summary is printed by this script, inside the step that fails, so
# `gh run view --log-failed` (Scripts/ci-logs.sh) shows it at the end of the failed step.
#
# Usage: Scripts/ci-xcodebuild.sh <name> <xcodebuild arguments...>
#   <name>   result bundle name; the bundle is $CI_RESULTS_DIR/<name>.xcresult
#            (CI_RESULTS_DIR defaults to $RUNNER_TEMP/xcresults, or a temporary folder outside the repository)
set -uo pipefail

name="${1:?usage: Scripts/ci-xcodebuild.sh <name> <xcodebuild arguments...>}"
shift

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
results="${CI_RESULTS_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/xcresults}"
bundle="$results/$name.xcresult"

mkdir -p "$results"
rm -rf "$bundle" # xcodebuild refuses to write over an existing bundle

status=0
xcodebuild "$@" -resultBundlePath "$bundle" || status=$?

"$here/xcresult-summary.sh" "$bundle" || true
exit "$status"
