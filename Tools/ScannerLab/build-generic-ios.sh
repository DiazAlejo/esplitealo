#!/usr/bin/env bash
# Compile-check Scanner Lab for a physical iPhone (no code signing).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
xcodebuild build \
  -project Tools/ScannerLab/ScannerLab.xcodeproj \
  -scheme ScannerLab \
  -destination 'generic/platform=iOS' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
