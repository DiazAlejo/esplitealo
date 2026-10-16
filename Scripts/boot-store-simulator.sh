#!/usr/bin/env bash
# Boot an iPhone simulator for the App Store screenshots and print its UDID. The device is looked up by name on the
# newest installed iOS runtime (18 or later) and created from its device type when the runner image does not have it.
# The status bar is set to the usual 9:41, full battery, full Wi-Fi and cell bars, so the pictures look the same.
#
# Usage: Scripts/boot-store-simulator.sh "iPhone 17 Pro Max"
set -euo pipefail

name="${1:?usage: Scripts/boot-store-simulator.sh \"iPhone 17 Pro Max\"}"

udid="$(xcrun simctl list devices available -j | python3 -I -c '
import json, sys

name = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
prefix = "com.apple.CoreSimulator.SimRuntime.iOS-"

def version(runtime):
    return tuple(int(part) for part in runtime.rsplit("iOS-", 1)[1].split("-"))

runtimes = sorted((r for r in devices if r.startswith(prefix) and version(r)[0] >= 18), key=version, reverse=True)
for runtime in runtimes:
    for device in devices[runtime]:
        if device["name"] == name and device.get("isAvailable", True):
            print(device["udid"])
            sys.exit(0)
print("")
' "$name")"

if [ -z "$udid" ]; then
  runtime="$(xcrun simctl list runtimes available -j | python3 -I -c '
import json, sys

runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "iOS" and r.get("isAvailable", True)]
runtimes.sort(key=lambda r: tuple(int(p) for p in r["version"].split(".")), reverse=True)
if not runtimes or int(runtimes[0]["version"].split(".")[0]) < 18:
    sys.exit("no iOS 18 or later simulator runtime is installed")
print(runtimes[0]["identifier"])
')"
  type="com.apple.CoreSimulator.SimDeviceType.$(printf '%s' "$name" | tr ' ' '-')"
  udid="$(xcrun simctl create "$name" "$type" "$runtime")"
fi

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >&2
xcrun simctl status_bar "$udid" override \
  --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 >&2
echo "$udid"
