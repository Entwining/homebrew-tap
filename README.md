# Entwining Homebrew tap

Homebrew packages for Entwining tools on Apple Silicon macOS. Formulae ship command-line tools as bottles. The Maskey cask installs the macOS app and its `mk` command.

## Install a tool

| Tool | Purpose | Install |
| --- | --- | --- |
| [Agent Guard](https://github.com/Entwining/agent-guard) | Blocks broad agent filesystem scans and recognizable credential reads. | `brew install entwining/tap/agent-guard` |
| [Maskey](https://github.com/Entwining/maskey) | Stores credentials in iCloud Keychain and supplies them to commands. | `brew install --cask entwining/tap/maskey` |
| [Rexume](https://github.com/Entwining/rexume) | Reopens agent conversations in restored Rex panes. | `brew install entwining/tap/rexume` |
| [sessidx](https://github.com/Entwining/sessidx) | Searches local coding agent sessions. | `brew install entwining/tap/sessidx` |

## Upstream contract

Upstream projects own tool releases and runtime packaging. This tap owns the Homebrew formulae, bottles, and casks. The [upstream contract](docs/maintenance.md#upstream-contract) defines release notifications and the `make build` interface.

## Automatic releases

The tap checks for upstream releases and opens update PRs. Formula updates [build and verify bottles before merging through the queue](docs/maintenance.md#automatic-releases).

## Manual publication and recovery

Bottles for PRs outside same-repository `bump-*` branches are [published manually](docs/maintenance.md#manual-publication-and-recovery). Retries reuse the reserved build and preserve existing assets.

## Adding or removing formulae

Adding a tool [changes its package, update workflow, and upstream notification](docs/maintenance.md#adding-or-removing-formulae). Casks install upstream app archives without building bottles.

## Workflow dependencies

[Generated Actions lockfiles](docs/maintenance.md#workflow-dependencies) pin readable action tags to commits. Regenerate the lockfile when changing action references.

## Repository settings

Publication relies on [the merge queue, receipt-tag protection, and Actions policies](docs/maintenance.md#repository-settings). The tap app has no ruleset bypass.

## Local checks

The [local checks](docs/maintenance.md#local-checks) validate workflow syntax and publication helpers. Regression tests use synthetic Git responses and bottle bytes.
