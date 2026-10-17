#!/usr/bin/env bash
# Download the App Store screenshots made by the "Store screenshots" workflow.
#
# Usage: Scripts/fetch-store-screenshots.sh [run-id] [output folder]
#   run-id         the workflow run to download from (default: the latest successful run of the workflow)
#   output folder  default: build/store-screenshots (git-ignored)
# One sub-folder per device comes out, for example build/store-screenshots/iphone-17-pro-max-1320x2868/es-light-01-home.png.
set -euo pipefail

repo="${ESPLITEALO_REPO:-DiazAlejo/esplitealo}"
run="${1:-}"
out="${2:-build/store-screenshots}"

if [ -z "$run" ]; then
  run="$(gh run list -R "$repo" --workflow store-screenshots.yml --status success --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
  [ -n "$run" ] || { echo "No successful run of store-screenshots.yml yet. Start one: gh workflow run store-screenshots.yml -R $repo --ref main" >&2; exit 1; }
fi

mkdir -p "$out"
gh run download "$run" -R "$repo" --pattern 'store-screenshots-*' -D "$out"
echo "Downloaded run $run into $out"
find "$out" -name '*.png' | sort
