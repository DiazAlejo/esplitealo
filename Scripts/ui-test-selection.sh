#!/usr/bin/env bash
# Prints the xcodebuild test selection for the UI test classes, so every class runs in exactly one CI job.
# The journey classes are the `final class` declarations in App/EsplitealoUITests/Journeys/*.swift; the folder is the
# only list there is.
#
#   Scripts/ui-test-selection.sh app                    all UI tests except the journey classes
#   Scripts/ui-test-selection.sh journeys <shard> <n>   the journey classes of shard <shard> (1-based) of <n>, round-robin
#
# Usage in CI: xcodebuild ... $(Scripts/ui-test-selection.sh app)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
journeys_dir="${UI_TEST_JOURNEYS_DIR:-$root/App/EsplitealoUITests/Journeys}"

journey_classes() {
  local file
  for file in "$journeys_dir"/*.swift; do
    [ -e "$file" ] || continue
    sed -n -E 's/^[[:space:]]*final class ([A-Za-z0-9_]+).*/\1/p' "$file"
  done | LC_ALL=C sort
}

case "${1:-}" in
  app)
    echo "-only-testing:EsplitealoUITests"
    while IFS= read -r class; do echo "-skip-testing:EsplitealoUITests/$class"; done < <(journey_classes)
    ;;
  journeys)
    shard="${2:-}"; total="${3:-}"
    case "$shard$total" in ''|*[!0-9]*) echo "usage: $0 journeys <shard> <total>" >&2; exit 2 ;; esac
    if [ "$shard" -lt 1 ] || [ "$shard" -gt "$total" ]; then echo "shard must be between 1 and $total" >&2; exit 2; fi
    index=0
    while IFS= read -r class; do
      if [ $((index % total + 1)) -eq "$shard" ]; then echo "-only-testing:EsplitealoUITests/$class"; fi
      index=$((index + 1))
    done < <(journey_classes)
    ;;
  *) echo "usage: $0 app | journeys <shard> <total>" >&2; exit 2 ;;
esac
