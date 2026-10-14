#!/usr/bin/env bash
# Print the UDID of an available iPhone simulator whose runtime is iOS <major>.x
# (default 18). Exits non-zero with a message on stderr when none exists.
#
# Usage: Scripts/ios-simulator-udid.sh [major]
set -euo pipefail

major="${1:-18}"

xcrun simctl list devices available -j | python3 -I -c '
import json, sys

major = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
prefix = "com.apple.CoreSimulator.SimRuntime.iOS-" + major + "-"

def runtime_key(runtime):
    return tuple(int(part) for part in runtime.rsplit("iOS-", 1)[1].split("-"))

for runtime in sorted((r for r in devices if r.startswith(prefix)), key=runtime_key, reverse=True):
    iphones = [d for d in devices[runtime] if d["name"].startswith("iPhone") and d.get("isAvailable", True)]
    if iphones:
        print(iphones[0]["udid"])
        sys.exit(0)

sys.exit("no available iPhone simulator on an iOS " + major + ".x runtime")
' "$major"
