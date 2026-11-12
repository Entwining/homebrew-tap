#!/usr/bin/env bash
set -euo pipefail

pull_request=$1
bottle_sha=$2
attempts=5
# GitHub has returned this rejection seconds after createCommitOnBranch wrote the bottle commit, and accepted the same head later.
# A head that has moved on keeps failing it; other errors may not mean the request was refused.
mismatch="GraphQL: Failed to add PR #$pull_request: expected head oid does not match the current head oid (enablePullRequestAutoMerge)"
for (( attempt = 1; attempt <= attempts; attempt++ )); do
  status=0
  { errors=$(gh pr merge "$pull_request" --repo "$GITHUB_REPOSITORY" --auto --match-head-commit "$bottle_sha" 2>&1 >&3); } 3>&1 || status=$?
  if [[ -n "$errors" ]]; then printf '%s\n' "$errors" >&2; fi
  if (( status == 0 )); then
    # gh exits 0 without sending the SHA-bound request for a pull request that is already in the merge queue.
    head=$(gh pr view "$pull_request" --repo "$GITHUB_REPOSITORY" --json headRefOid --jq .headRefOid)
    if [[ "$head" != "$bottle_sha" ]]; then
      echo "::error::Pull request #$pull_request has head $head instead of bottle commit $bottle_sha."
      exit 1
    fi
    exit 0
  fi
  if [[ "$errors" != "$mismatch" ]] || (( attempt == attempts )); then exit "$status"; fi
  sleep 5
done
