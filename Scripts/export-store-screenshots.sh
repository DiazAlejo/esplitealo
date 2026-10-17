#!/usr/bin/env bash
# Turn the screenshots that StoreScreenshotTests attached to a test result bundle into plain PNG files named
# <language>-<appearance>-<number>-<screen>.png (for example es-light-01-home.png), and check each one against what
# App Store Connect accepts: PNG, no alpha channel, and the size you expect.
#
# Usage: Scripts/export-store-screenshots.sh <Result.xcresult> <output folder> [WIDTHxHEIGHT]
#   WIDTHxHEIGHT  portrait pixel size every picture must have (for example 1320x2868). Omit to skip the size check.
# Exits 1 when no screenshot was found or a picture does not pass the checks.
set -euo pipefail

bundle="${1:?usage: Scripts/export-store-screenshots.sh <Result.xcresult> <output folder> [WIDTHxHEIGHT]}"
out="${2:?usage: Scripts/export-store-screenshots.sh <Result.xcresult> <output folder> [WIDTHxHEIGHT]}"
expected="${3:-}"

work="$(mktemp -d "${TMPDIR:-/tmp}/store-screenshots.XXXXXX")"
trap 'rm -rf "$work"' EXIT

xcrun xcresulttool export attachments --path "$bundle" --output-path "$work"
mkdir -p "$out"

# manifest.json lists every attachment; keep the PNGs whose name looks like <language>-<appearance>-<NN>-<screen>.
python3 -I - "$work" "$out" <<'PY'
import json, os, re, shutil, sys

work, out = sys.argv[1], sys.argv[2]
with open(os.path.join(work, "manifest.json")) as handle:
    manifest = json.load(handle)

wanted = re.compile(r"^((?:es|en)-(?:light|dark)-\d\d-[a-z-]+)(?:_\d+_[0-9A-Fa-f-]{36})?(?:\.png)?$")
count = 0
for test in manifest:
    attachments = test.get("attachments", [])
    if isinstance(attachments, dict):
        attachments = [attachments]
    for attachment in attachments:
        match = wanted.match(attachment.get("suggestedHumanReadableName", ""))
        if not match:
            continue
        shutil.copyfile(os.path.join(work, attachment["exportedFileName"]), os.path.join(out, match.group(1) + ".png"))
        count += 1
print("exported %d screenshots to %s" % (count, out))
sys.exit(0 if count else 1)
PY

status=0
for file in "$out"/*.png; do
  width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')"
  alpha="$(sips -g hasAlpha "$file" | awk '/hasAlpha/ {print $2}')"
  problem=""
  [ "$alpha" = "no" ] || problem="$problem has an alpha channel;"
  if [ -n "$expected" ] && [ "${width}x${height}" != "$expected" ]; then problem="$problem expected $expected;"; fi
  printf '%-28s %sx%s alpha=%s%s\n' "$(basename "$file")" "$width" "$height" "$alpha" "${problem:+  PROBLEM:$problem}"
  [ -z "$problem" ] || status=1
done
exit "$status"
