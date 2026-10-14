#!/usr/bin/env bash
# Build Scanner Lab for a connected iPhone. Pass your Apple development team ID.
# Example: Tools/ScannerLab/build-device.sh ABCDE12345
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <DEVELOPMENT_TEAM> [device name]" >&2
  echo "Find team ID in Xcode → Settings → Accounts → your team → Team ID." >&2
  exit 1
fi
TEAM="$1"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
DEST='platform=iOS'
if [[ -n "${2:-}" ]]; then
  DEST="platform=iOS,name=$2"
fi
xcodebuild build \
  -project Tools/ScannerLab/ScannerLab.xcodeproj \
  -scheme ScannerLab \
  -destination "$DEST" \
  -skipPackagePluginValidation \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic
