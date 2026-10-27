# Entwining Homebrew tap

Homebrew formulae and bottles for Entwining tools on Apple Silicon macOS.

| Tool | Purpose | Install |
| --- | --- | --- |
| [Agent Guard](https://github.com/Entwining/agent-guard) | Guards agent filesystem scans and credential reads. | `brew install entwining/tap/agent-guard` |
| [rexume](https://github.com/Entwining/rexume) | Restores Rex sessions and agent conversations. | `brew install entwining/tap/rexume` |
| [sessidx](https://github.com/Entwining/sessidx) | Searches local coding agent sessions. | `brew install entwining/tap/sessidx` |

## Upstream contract

Upstream projects own tool releases and runtime packaging; this tap owns their Homebrew formulae and bottles. The updater follows GitHub's latest stable Release, limited to `v0.MINOR.PATCH` tags. Notify the tap with a `<formula>-release` repository dispatch after creating the Release; tags alone, drafts and prereleases do not qualify. Moving beyond `0.x` requires updating the formula livecheck filters and the updater's version validation first.

Each formula installs the package staged by upstream `make build`. Coordinate changes to its interface (`OUT`, `CARGO_TARGET_DIR`) or build tools in a tap PR that still builds the currently pinned upstream version: add build dependencies before the release that needs them and remove them after. When a recipe change rebuilds an already bottled version, increment the formula's package `revision` and keep its upstream commit pin.

## Automatic releases

`update.yml` handles upstream notifications, scheduled checks and manual formula selection. Homebrew updates and audits the formula; GitHub's `createCommitOnBranch` commits it, and Homebrew Actions opens its PR.

Release automation and Renovate use Conventional Commits. The required `commit-policy` check validates PR titles using the main branch's [action-semantic-pull-request](https://github.com/amannn/action-semantic-pull-request) configuration. GitHub squash commits use the PR title and body.

`test-bot` builds and tests the formula from source and audits candidate bottle metadata. The publisher reserves that tested build in a protected `publish/<formula>-<version>[.<rebuild>]` receipt tag before uploading Release assets, then appends bottle metadata to the reviewed PR head. GitHub squash merges the original PR after required checks pass and deletes its branch.

`bottle-ready` verifies the receipt, downloads and pours the bottle, and runs `brew test`. Installation changes need a matching bottle even at the same package version.

PR branches must be up to date. The publisher rebases the app's own `bump-*` branches and merges main into contributor branches to preserve their published history. Scheduled reconciliation resumes open, same-repository `bump-*` PRs.

## Manual publication and recovery

Bottles for PRs outside same-repository `bump-*` branches are published manually. Dispatch **Publish bottles** with the PR number and reviewed head SHA. An optional `run_id` selects its successful `pull_request` source build. A standalone **brew test-bot** dispatch does not qualify as a tested PR head.

For forks, the publisher prepares a bottle commit in this repository and prints commands to apply it to the original PR. Apply it before updating the fork with main, then wait for checks and dispatch publication for the new head. The original PR remains open until GitHub merges it.

A retry adopts the receipt's original artifact and completes that reserved build before synchronizing the PR branch. It reuses matching Release assets, uploads missing files, verifies public downloads and attests the published bytes. Conflicting assets or receipts stop publication; existing assets are never overwritten. If the selected artifact expires before completion, preserve the receipt and use a new bottle rebuild or formula revision. A different build cannot claim the reserved filenames.

Keep formula execution and audits in ordinary PR CI. Privileged publication treats formula Ruby as AST data and creates the app token after uploads and attestation.

## Adding or removing formulae

Update `Formula/`, the dispatch filters, manual choices and matrix in `.github/workflows/update.yml`, and the installation table together. Add or remove the upstream release notification and its tap App access with the tool.

## Workflow dependencies

Workflows use readable action tags. GitHub's generated `.github/workflows/actions.lock` pins their commits and repository identities, including transitive action dependencies. Renovate updates references and regenerates the lockfile together, using its native GitHub Actions manager.

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
