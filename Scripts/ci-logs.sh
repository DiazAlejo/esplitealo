#!/usr/bin/env bash
# Print why the latest CI run of a branch failed, using the gh CLI: the state of every job, then the logs of the
# failed steps (the xcodebuild steps end with the test failure summary from Scripts/xcresult-summary.sh).
#
# Usage: Scripts/ci-logs.sh [options]
#   -b, --branch NAME     branch to look at (default: the current branch)
#   -w, --workflow NAME   workflow to look at (default: CI)
#   -R, --repo OWNER/REPO repository (default: the one gh finds from the git remote)
#   -n, --lines N         print only the last N lines of the failed logs (default: 300; 0 prints everything)
#       --wait            if the run is still going, wait for it to finish first
#
# Exit status: 0 the run passed, 1 it failed, 2 it is not finished or there is no run, 3 bad usage.
set -euo pipefail

branch=""
workflow="CI"
repo=""
lines=300
wait=0

usage() { sed -n '2,/^set /p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    -b|--branch) branch="${2:?--branch needs a value}"; shift 2 ;;
    -w|--workflow) workflow="${2:?--workflow needs a value}"; shift 2 ;;
    -R|--repo) repo="${2:?--repo needs a value}"; shift 2 ;;
    -n|--lines) lines="${2:?--lines needs a value}"; shift 2 ;;
    --wait) wait=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 3 ;;
  esac
done

case "$lines" in ''|*[!0-9]*) echo "--lines must be a number" >&2; exit 3 ;; esac

if [ -z "$branch" ]; then
  branch="$(git branch --show-current)"
  [ -n "$branch" ] || { echo "not on a branch (detached HEAD): pass --branch" >&2; exit 3; }
fi

gh_args=()
[ -z "$repo" ] || gh_args+=(-R "$repo")

run="$(gh run list "${gh_args[@]}" --branch "$branch" --workflow "$workflow" --limit 1 \
  --json databaseId,status,conclusion,headSha,url,displayTitle \
  --jq '.[0] // empty | [.databaseId, .status, .conclusion, .headSha, .url, .displayTitle] | @tsv')"

if [ -z "$run" ]; then
  echo "No \"$workflow\" run found for branch $branch. Push the branch (or open a PR) to start one." >&2
  exit 2
fi

IFS=$'\t' read -r id status conclusion sha url title <<<"$run"

if [ "$status" != "completed" ] && [ "$wait" = 1 ]; then
  echo "Run $id is $status; waiting for it to finish..."
  gh run watch "${gh_args[@]}" "$id" >/dev/null || true
  IFS=$'\t' read -r status conclusion < <(gh run view "${gh_args[@]}" "$id" --json status,conclusion --jq '[.status, .conclusion] | @tsv')
fi

echo "Run $id on $branch: $title"
echo "$url"
local_sha="$(git rev-parse HEAD 2>/dev/null || true)"
if [ -n "$local_sha" ] && [ "$local_sha" != "$sha" ]; then
  echo "Note: this run is for ${sha:0:9}, not your HEAD ${local_sha:0:9}. Push, then run this again."
fi

if [ "$status" != "completed" ]; then
  echo "Status: $status (not finished). Run again with --wait, or later."
  exit 2
fi

echo "Conclusion: $conclusion"
echo
echo "Jobs:"
gh run view "${gh_args[@]}" "$id" --json jobs --jq '.jobs[] | "  \(.conclusion // .status)\t\(.name)"'

if [ "$conclusion" = "success" ]; then
  exit 0
fi

echo
echo "Logs of the failed steps:"
if [ "$lines" -gt 0 ]; then
  gh run view "${gh_args[@]}" "$id" --log-failed | tail -n "$lines"
else
  gh run view "${gh_args[@]}" "$id" --log-failed
fi
exit 1
