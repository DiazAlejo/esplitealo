#!/usr/bin/env bash
# Print a short, plain-text summary of an .xcresult bundle: counts, and for every failed test its name and the
# failure message. It is how a worker reads why a UI or snapshot test failed without a simulator.
# When GITHUB_STEP_SUMMARY is set the same text is appended there as Markdown.
#
# Usage: Scripts/xcresult-summary.sh <path/to/Result.xcresult>
# Always exits 0: a summary must never hide the real test result.
set -uo pipefail

bundle="${1:?usage: Scripts/xcresult-summary.sh <Result.xcresult>}"

if [ ! -d "$bundle" ]; then
  echo "== Test result summary: no result bundle at $bundle (the build probably failed before any test ran; read the xcodebuild errors above)"
  exit 0
fi

if ! json="$(xcrun xcresulttool get test-results summary --path "$bundle" --compact 2>&1)"; then
  echo "== Test result summary: could not read $bundle"
  echo "$json"
  exit 0
fi

text="$(printf '%s' "$json" | python3 -I -c '
import json, sys

try:
    summary = json.load(sys.stdin)
except ValueError:
    print("(the result summary was not JSON)")
    sys.exit(0)

failures = summary.get("testFailures", [])
print("Result: {}  (passed {}, failed {}, skipped {}, expected failures {}, total {})".format(
    summary.get("result", "unknown"),
    summary.get("passedTests", 0),
    summary.get("failedTests", 0),
    summary.get("skippedTests", 0),
    summary.get("expectedFailures", 0),
    summary.get("totalTestCount", 0),
))
for device in summary.get("devicesAndConfigurations", []):
    d = device.get("device", {})
    print("Device: {} ({} {})".format(d.get("deviceName", "?"), d.get("platform", "?"), d.get("osVersion", "?")))
if failures:
    print("")
    print("Failed tests ({}):".format(len(failures)))
    for failure in failures:
        name = failure.get("testIdentifierString") or failure.get("testName") or "?"
        target = failure.get("targetName")
        print("- {}{}".format(name, " [{}]".format(target) if target else ""))
        message = (failure.get("failureText") or "").strip()
        for line in message.splitlines()[:12]:
            print("    " + line)
elif summary.get("result") == "Failed":
    print("")
    print("The run failed but no test failed: it was a build error or a crash. Read the xcodebuild output above.")
')"

echo
echo "== Test result summary ($(basename "$bundle"))"
echo "$text"
echo

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Test results: $(basename "$bundle" .xcresult)"
    echo
    echo '```text'
    echo "$text"
    echo '```'
    echo
  } >> "$GITHUB_STEP_SUMMARY"
fi
