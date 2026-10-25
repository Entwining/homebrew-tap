# Entwining Homebrew tap

```sh
brew install entwining/tap/agent-guard
brew install entwining/tap/rexume
brew install entwining/tap/sessidx
```

## Release pull requests

Upstream releases dispatch `agent-guard-release`, `rexume-release`, or `sessidx-release`. `update.yml` also checks for releases on its schedule and can be dispatched for one formula. Homebrew updates and audits the formula; Homebrew Actions creates its commit and PR.

Version commits and PR titles use `chore(<formula>): update to <version>`. Bottle commits use `build(<formula>): add <version> bottle`. Renovate uses Conventional Commits for workflow updates. The required `commit-policy` check validates PR titles with [action-semantic-pull-request](https://github.com/amannn/action-semantic-pull-request), and GitHub squash commits use the PR title and body.

`test-bot` builds from source, packages the license notices and runs the formula tests. Before uploading its artifact, it merges and audits the candidate bottle metadata with Homebrew. The publisher fixes the successful run, attempt, artifact ID and digest before uploading any Release assets. It verifies the tested merge commit contains the PR head and the exact formula blob, then checks each bottle's upstream revision and checksum. Annotated `publish/<formula>-<version>[.<rebuild>]` tags retain that selection and the tested source.

The publisher appends bottle metadata to the original PR with GitHub's `createCommitOnBranch` expected-head precondition. GitHub auto-merge waits for `test-bot`, `bottle-ready`, and `commit-policy`. `bottle-ready` checks the formula against its receipt, fetches and pours the bottle, and runs `brew test`. Changes to installation logic require a matching new bottle even when the package version stays the same.

The repository requires PR branches to be up to date. The publisher uses GitHub's expected-head branch update API when a release PR falls behind: it rebases the app's own `bump-*` branches and merges updates into contributor branches to preserve their published history. Scheduled reconciliation resumes open, same-repository `bump-*` PRs. GitHub owns the squash merge and branch deletion.

## Manual publication and recovery

Dispatch **Publish bottles** with the PR number and reviewed head SHA. An optional `run_id` selects its successful `pull_request` source build. A standalone formula build dispatched through **brew test-bot** does not qualify as a tested PR head.

Forks require manual dispatch. The publisher prepares a bottle commit on this repository and prints the commands to apply it to the original PR. Apply it before updating the fork with main, then wait for checks and dispatch publication for the new head. The original PR remains open until GitHub merges it.

Rerunning publication adopts the receipt's original artifact and completes the reserved build before synchronizing its PR branch. It reuses matching Release assets, uploads missing files, verifies their public downloads and attests the published bytes. It never overwrites an existing asset or replaces the original PR. A conflicting asset or receipt stops publication. If the selected artifact expires while publication is incomplete, preserve the receipt and use a new bottle rebuild or formula revision; automation does not publish a different build under the claimed filenames.

The read-only resolver identifies the current PR before publication is serialized. The publisher derives its plan from GitHub and the artifact, handles formula Ruby only as AST data, and creates the app token after uploads and attestation. Formula execution and audits stay in the ordinary PR test workflow. Publication posts no PR comments.

## Repository settings

Configure these together with the workflows:

- Allow squash merges and auto-merge. Disable merge commits and rebase merges. Set squash defaults to `PR_TITLE` and `PR_BODY`; enable branch deletion after merge.
- In the active `main` ruleset, require `test-bot`, `bottle-ready`, and `commit-policy` from GitHub Actions, with branches required to be up to date. Allow only squash merges and require linear history. Keep deletion and force-push restrictions. The tap app has no bypass.
- Protect `refs/tags/publish/**` with an active tag ruleset that prohibits updates and deletion, with no bypass actors. Creation remains allowed.
- Keep the existing `TAP_CLIENT_ID` variable and `TAP_APP_PRIVATE_KEY` secret. The app needs contents and pull-request write access; the workflow token reads Actions artifacts.

For deployment, pause publication and update workflows, and let active publishers finish before merging the workflow changes. The bootstrap PR changes no formula. Once it is merged, apply the required checks and repository settings, then enable **Publish bottles** and **Update formulae**. This keeps publication paused until the source-bound bottle gate is active. Existing release PRs need a fresh PR build with the attempt-scoped artifact name.

## Local checks

```sh
actionlint
shellcheck .github/scripts/resolve-publish.sh
brew install-bundler-gems --add-groups=ast,style
python3 -m unittest discover -s .github/scripts -p '*_test.py'
brew style .github/scripts/bottle_receipt.rb
```

The tests execute the production Ruby helper with synthetic Git responses and bottle bytes. GitHub writes remain outside the local test process.
