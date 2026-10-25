# Entwining Homebrew tap

Homebrew formulae and bottles for Entwining tools on Apple Silicon macOS.

| Tool | Purpose | Install |
| --- | --- | --- |
| [Agent Guard](https://github.com/Entwining/agent-guard) | Guards agent filesystem scans and credential reads. | `brew install entwining/tap/agent-guard` |
| [rexume](https://github.com/Entwining/rexume) | Restores Rex sessions and agent conversations. | `brew install entwining/tap/rexume` |
| [sessidx](https://github.com/Entwining/sessidx) | Searches local coding agent sessions. | `brew install entwining/tap/sessidx` |

## Automatic releases

Upstream projects own tool releases; this tap owns their Homebrew formulae and bottles. Releases dispatch `agent-guard-release`, `rexume-release`, or `sessidx-release`. `update.yml` also checks on its schedule and accepts a manual dispatch for one formula. Homebrew updates and audits the formula; Homebrew Actions creates its commit and PR.

Version commits and PR titles use `chore(<formula>): update to <version>`, and bottle commits use `build(<formula>): add <version> bottle`. Renovate uses Conventional Commits for workflow updates. The required `commit-policy` check validates titles using the main branch's [action-semantic-pull-request](https://github.com/amannn/action-semantic-pull-request) configuration. GitHub squash commits use the PR title and body.

`test-bot` builds from source, packages license notices, runs formula tests, then merges and audits candidate bottle metadata before uploading it. The publisher reserves the successful run, attempt, artifact ID and digest before uploading Release assets. It verifies that the tested tree contains the PR head and identical formula blob, and checks each bottle's upstream revision and checksum. Annotated `publish/<formula>-<version>[.<rebuild>]` tags retain that selection and its tested source.

The publisher appends bottle metadata to the original PR with GitHub's expected-head precondition. Auto-merge waits for `test-bot`, `bottle-ready`, and `commit-policy`. `bottle-ready` verifies the source-bound receipt, fetches and pours the bottle, and runs `brew test`. Installation changes need a matching bottle even at the same package version.

PR branches must be up to date. The publisher rebases the app's own `bump-*` branches and merges main into contributor branches to preserve their published history. Scheduled reconciliation resumes open, same-repository `bump-*` PRs. GitHub owns the squash merge and branch deletion.

## Manual publication and recovery

Dispatch **Publish bottles** with the PR number and reviewed head SHA. An optional `run_id` selects its successful `pull_request` source build. A standalone **brew test-bot** dispatch does not qualify as a tested PR head.

Forks require manual dispatch. The publisher prepares a bottle commit in this repository and prints commands to apply it to the original PR. Apply it before updating the fork with main, then wait for checks and dispatch publication for the new head. The original PR remains open until GitHub merges it.

A retry adopts the receipt's original artifact and completes that reserved build before synchronizing the PR branch. It reuses matching Release assets, uploads missing files, verifies public downloads and attests the published bytes. Conflicting assets or receipts stop publication; existing assets are never overwritten. If the selected artifact expires before completion, preserve the receipt and use a new bottle rebuild or formula revision. A different build cannot claim the reserved filenames.

The read-only resolver identifies the PR before publication is serialized. Publication treats formula Ruby as AST data and creates the app token after uploads and attestation. Formula execution and audits run in ordinary PR CI. Publication posts no PR comments.

## Workflow dependencies

Workflows use readable action tags. GitHub's generated `.github/workflows/actions.lock` pins their commits and repository identities, including transitive action dependencies. Renovate updates references and regenerates the lockfile together, using its native GitHub Actions manager. Homebrew Actions' calendar tags use Renovate's `loose` versioning.

After changing action references or adding a workflow, run `gh actions-lock` and commit its generated changes together. Install the tool with `gh extension install github/gh-actions-lock`.

## Repository settings

- Allow squash merges and auto-merge. Disable merge commits and rebase merges. Set squash defaults to `PR_TITLE` and `PR_BODY`; enable branch deletion after merge.
- In the active `main` ruleset, require `test-bot`, `bottle-ready`, and `commit-policy` from GitHub Actions, with branches required to be up to date. Allow only squash merges and require linear history. Keep deletion and force-push restrictions; the tap app has no bypass.
- Protect `refs/tags/publish/**` with an active tag ruleset prohibiting updates and deletion, with no bypass actors. Allow creation.
- Require lockfiles through an active Actions policy targeting all workflows.
- In a separate active Actions event policy, target only `.github/workflows/commit-policy.yml` and allow only `pull_request_target`. This keeps the title rule defined by main when GitHub restricts that event by default.
- Keep `TAP_CLIENT_ID` as a repository variable and `TAP_APP_PRIVATE_KEY` as a secret. The app needs contents and pull-request write access; the workflow token reads Actions artifacts.

## Local checks

```sh
gh actions-lock --verify
actionlint
shellcheck .github/scripts/resolve-publish.sh
brew install-bundler-gems --add-groups=ast,style
python3 -m unittest discover -s .github/scripts -p '*_test.py'
brew style .github/scripts/bottle_receipt.rb
```

Regression tests execute the production helpers with synthetic Git responses and bottle bytes. GitHub writes belong to the workflows.
