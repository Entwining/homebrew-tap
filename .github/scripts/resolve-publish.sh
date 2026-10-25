#!/usr/bin/env bash
set -euo pipefail

directory=$1
mkdir -p "$directory"
pull_request=${PULL_REQUEST:-}
if [[ -z "$pull_request" ]]; then
  pull_request=$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$TRIGGER_BRANCH" --state open --json number \
    --jq 'if length == 0 then 0 elif length == 1 then .[0].number else error("Ambiguous source branch") end')
fi
if [[ "$pull_request" == 0 ]]; then
  echo 'state=inactive' >> "$GITHUB_OUTPUT"
  exit 0
fi
[[ "$pull_request" =~ ^[1-9][0-9]*$ ]]
gh api "repos/$GITHUB_REPOSITORY/pulls/$pull_request" \
  --jq '{number, node_id, author: .user.login, state, merged, draft, mergeable_state, head: {sha: .head.sha, ref: .head.ref, repository: .head.repo.full_name}, base: .base.ref}' > "$directory/pr.json"
head_sha=$(jq -r .head.sha "$directory/pr.json")
if ! jq -e --arg expected "$EXPECTED_SHA" '
  .state == "open" and .merged == false and .draft == false and .base == "main" and .head.sha == $expected
' "$directory/pr.json" > /dev/null; then
  echo 'state=inactive' >> "$GITHUB_OUTPUT"
  exit 0
fi
if [[ -n ${TRIGGER_BRANCH:-} ]]; then
  jq -e --arg branch "$TRIGGER_BRANCH" --arg repository "$GITHUB_REPOSITORY" \
    '.head.ref == $branch and .head.repository == $repository' "$directory/pr.json" > /dev/null
fi
if [[ ${2:-} == --identify ]]; then
  {
    echo 'state=active'
    echo "pull_request=$pull_request"
    echo "head_sha=$head_sha"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi
helper="$(dirname -- "${BASH_SOURCE[0]}")/bottle_receipt.rb"
git fetch --no-tags origin "$head_sha" 'refs/tags/publish/*:refs/tags/publish/*'
gh api "repos/$GITHUB_REPOSITORY/pulls/$pull_request/files" --paginate --slurp \
  --jq '[.[][] | select(.status != "removed" and (.filename | test("^Formula/[^/]+\\.rb$"))) | .filename]' > "$directory/paths.json"
jq -n --arg repository "$GITHUB_REPOSITORY" --slurpfile pr "$directory/pr.json" --slurpfile paths "$directory/paths.json" '
  {repository: $repository, pull_request: $pr[0].number, head_sha: $pr[0].head.sha,
   branch: $pr[0].head.ref, head_repository: $pr[0].head.repository, paths: $paths[0]}
' > "$directory/selection.json"
brew ruby "$helper" status "$directory/selection.json" > "$directory/status.json"
state=$(jq -r .state "$directory/status.json")
if [[ "$state" == prepare ]]; then
  brew ruby "$helper" seed "$directory/selection.json" > "$directory/seed.json"
fi
# Resume the reserved build before changing the head its receipt binds.
if jq -e '.mergeable_state == "behind"' "$directory/pr.json" > /dev/null &&
   { [[ "$state" == ready ]] || jq -e 'length == 0' "$directory/seed.json" > /dev/null; }; then
  if [[ $(jq -r .head.repository "$directory/pr.json") != "$GITHUB_REPOSITORY" ]]; then
    echo 'Update the fork branch with main before dispatching publication for its new reviewed head.' >> "$GITHUB_STEP_SUMMARY"
    echo 'state=waiting' >> "$GITHUB_OUTPUT"
    exit 0
  fi
  {
    echo 'state=sync'
    echo "pull_request=$pull_request"
    echo "head_sha=$head_sha"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi
if [[ "$state" == prepare ]]; then
  run_id=$(jq -r '.run_id // empty' "$directory/seed.json")
  attempt=$(jq -r '.run_attempt // empty' "$directory/seed.json")
  if [[ -z "$run_id" ]]; then
    run_id=${SOURCE_RUN_ID:-}
    attempt=${SOURCE_RUN_ATTEMPT:-}
    if [[ -z "$run_id" ]]; then
      gh api "repos/$GITHUB_REPOSITORY/actions/workflows/tests.yml/runs?event=pull_request&head_sha=$head_sha" \
        --jq '.workflow_runs | max_by(.run_number)' > "$directory/latest.json"
      run_id=$(jq -r '.id // empty' "$directory/latest.json")
    else
      gh api "repos/$GITHUB_REPOSITORY/actions/runs/$run_id" > "$directory/latest.json"
    fi
    if [[ -z "$run_id" ]]; then
      echo 'state=waiting' >> "$GITHUB_OUTPUT"
      exit 0
    fi
    if [[ -z "$attempt" ]]; then attempt=$(jq -r .run_attempt "$directory/latest.json"); fi
  fi
  [[ "$run_id" =~ ^[1-9][0-9]*$ && "$attempt" =~ ^[1-9][0-9]*$ ]]
  gh api "repos/$GITHUB_REPOSITORY/actions/runs/$run_id/attempts/$attempt" > "$directory/run.json"
  if ! jq -e '.conclusion == "success"' "$directory/run.json" > /dev/null; then
    echo 'state=waiting' >> "$GITHUB_OUTPUT"
    exit 0
  fi
  artifact_id=$(jq -r '.artifact_id // empty' "$directory/seed.json")
  if [[ -z "$artifact_id" ]]; then
    artifact_id=$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$run_id/artifacts?name=bottles_macos-26-$attempt" \
      --paginate --slurp --jq '[.[] | .artifacts[]] | if length == 1 then .[0].id else error("Expected one source-build artifact") end')
  fi
  [[ "$artifact_id" =~ ^[1-9][0-9]*$ ]]
  gh api "repos/$GITHUB_REPOSITORY/actions/artifacts/$artifact_id" > "$directory/artifact.json"
  jq -e --slurpfile seed "$directory/seed.json" '
    ($seed[0].artifact_digest == null or .digest == $seed[0].artifact_digest) and .expired == false
  ' "$directory/artifact.json" > /dev/null
  jq --slurpfile run "$directory/run.json" --slurpfile artifact "$directory/artifact.json" \
    '. + {run: $run[0], artifact: $artifact[0]}' "$directory/selection.json" > "$directory/selection.new.json"
  mv "$directory/selection.new.json" "$directory/selection.json"
  {
    echo "run_id=$run_id"
    echo "artifact_id=$artifact_id"
  } >> "$GITHUB_OUTPUT"
fi
{
  echo "state=$state"
  echo "pull_request=$pull_request"
  echo "head_sha=$head_sha"
} >> "$GITHUB_OUTPUT"
