#!/usr/bin/env bash
# Tests for Scripts/export-store-screenshots.sh and Scripts/fetch-store-screenshots.sh, with stub xcrun, sips and gh
# programs, so no simulator or Xcode is needed.
#
# Usage: Scripts/tests/store-screenshots-test.sh
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

# xcrun xcresulttool export attachments --path <bundle> --output-path <dir>: files plus a manifest.json like Xcode 26's.
cat > "$work/bin/xcrun" <<'STUB'
#!/usr/bin/env bash
out=""
while [ $# -gt 0 ]; do [ "$1" = "--output-path" ] && out="$2"; shift; done
mkdir -p "$out"
echo "png-a" > "$out/AAAA.png"; echo "png-b" > "$out/BBBB.png"; echo "png-c" > "$out/CCCC.png"; echo "noise" > "$out/DDDD.txt"
case "${STUB_MANIFEST:-normal}" in
  normal) cat > "$out/manifest.json" <<'JSON'
[{"testIdentifier":"StoreScreenshotTests/testSpanishLight()","attachments":[
  {"exportedFileName":"AAAA.png","suggestedHumanReadableName":"es-light-01-home_0_5F2E7B0C-1D2A-4C55-9C0B-3A7E1B2C4D5E.png","isAssociatedWithFailure":false},
  {"exportedFileName":"BBBB.png","suggestedHumanReadableName":"es-light-05-share_0_6F2E7B0C-1D2A-4C55-9C0B-3A7E1B2C4D5E","isAssociatedWithFailure":false},
  {"exportedFileName":"DDDD.txt","suggestedHumanReadableName":"Debug description_1_7F2E7B0C-1D2A-4C55-9C0B-3A7E1B2C4D5E.txt","isAssociatedWithFailure":false}]},
 {"testIdentifier":"StoreScreenshotTests/testEnglishLight()","attachments":
  {"exportedFileName":"CCCC.png","suggestedHumanReadableName":"en-dark-03-mark_0_8F2E7B0C-1D2A-4C55-9C0B-3A7E1B2C4D5E.png","isAssociatedWithFailure":false}}]
JSON
  ;;
  none) echo '[{"testIdentifier":"x","attachments":[{"exportedFileName":"DDDD.txt","suggestedHumanReadableName":"Screenshot_1_x.png","isAssociatedWithFailure":false}]}]' > "$out/manifest.json" ;;
esac
STUB

# sips -g <property> <file>: the size and alpha come from the environment.
cat > "$work/bin/sips" <<'STUB'
#!/usr/bin/env bash
file="$3"
echo "$file"
case "$2" in
  pixelWidth) echo "  pixelWidth: ${STUB_WIDTH:-1320}" ;;
  pixelHeight) echo "  pixelHeight: ${STUB_HEIGHT:-2868}" ;;
  hasAlpha) echo "  hasAlpha: ${STUB_ALPHA:-no}" ;;
esac
STUB

cat > "$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB_LOG"
case "$1 $2" in
  "run list") [ -z "${STUB_RUN:-}" ] || echo "$STUB_RUN" ;;
  "run download") mkdir -p "$9/store-screenshots-iphone-17-pro-max-1320x2868"; touch "$9/store-screenshots-iphone-17-pro-max-1320x2868/es-light-01-home.png" ;;
esac
STUB
chmod +x "$work/bin/"*
export STUB_LOG="$work/gh.log"
: > "$STUB_LOG"

export_shots() { PATH="$work/bin:$PATH" "$root/Scripts/export-store-screenshots.sh" "$@" 2>&1; }

out="$(export_shots "$work/R.xcresult" "$work/out" 1320x2868)"; code=$?
check "export: exits 0 for good pictures" "$([ $code -eq 0 ] && echo 0 || echo 1)"
check "export: strips the _N_UUID suffix and keeps .png" "$([ -f "$work/out/es-light-01-home.png" ] && [ -f "$work/out/es-light-05-share.png" ] && echo 0 || echo 1)"
check "export: handles an attachments object (not an array)" "$([ -f "$work/out/en-dark-03-mark.png" ] && echo 0 || echo 1)"
check "export: ignores attachments that are not screenshots" "$([ "$(ls "$work/out" | wc -l | tr -d ' ')" = 3 ] && echo 0 || echo 1)"
check "export: copies the right file" "$([ "$(cat "$work/out/es-light-05-share.png")" = "png-b" ] && echo 0 || echo 1)"
check "export: reports size and alpha" "$(contains "$out" 'es-light-01-home.png' && contains "$out" '1320x2868 alpha=no' && echo 0 || echo 1)"

out="$(STUB_ALPHA=yes export_shots "$work/R.xcresult" "$work/out2" 1320x2868)"; code=$?
check "export: an alpha channel fails" "$([ $code -eq 1 ] && contains "$out" 'has an alpha channel' && echo 0 || echo 1)"

out="$(STUB_WIDTH=1179 STUB_HEIGHT=2556 export_shots "$work/R.xcresult" "$work/out3" 1320x2868)"; code=$?
check "export: a wrong size fails" "$([ $code -eq 1 ] && contains "$out" 'expected 1320x2868' && echo 0 || echo 1)"

out="$(STUB_WIDTH=1179 STUB_HEIGHT=2556 export_shots "$work/R.xcresult" "$work/out4")"; code=$?
check "export: without an expected size any size passes" "$([ $code -eq 0 ] && echo 0 || echo 1)"

out="$(STUB_MANIFEST=none export_shots "$work/R.xcresult" "$work/out5")"; code=$?
check "export: no screenshot at all fails" "$([ $code -eq 1 ] && contains "$out" 'exported 0 screenshots' && echo 0 || echo 1)"

# --- fetch ------------------------------------------------------------------------------------------------------
fetch() { (cd "$work" && PATH="$work/bin:$PATH" "$root/Scripts/fetch-store-screenshots.sh" "$@" 2>&1); }

export STUB_RUN=""
out="$(fetch)"; code=$?
check "fetch: no successful run explains how to start one" "$([ $code -eq 1 ] && contains "$out" 'gh workflow run store-screenshots.yml' && echo 0 || echo 1)"

export STUB_RUN="987"
: > "$STUB_LOG"
out="$(fetch)"; code=$?
check "fetch: downloads the latest successful run into build/store-screenshots" "$([ $code -eq 0 ] && grep -q 'run download 987 -R DiazAlejo/esplitealo --pattern store-screenshots-\* -D build/store-screenshots' "$STUB_LOG" && echo 0 || echo 1)"
check "fetch: lists the pictures" "$(contains "$out" 'es-light-01-home.png' && echo 0 || echo 1)"

: > "$STUB_LOG"
out="$(fetch 123 elsewhere)"
check "fetch: a run id and a folder can be given" "$(grep -q 'run download 123 .* -D elsewhere' "$STUB_LOG" && ! grep -q 'run list' "$STUB_LOG" && echo 0 || echo 1)"

echo
if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
