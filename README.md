# Entwining Homebrew tap

Homebrew packages for Entwining tools on Apple Silicon macOS. Formulae ship command-line tools as bottles. The Maskey cask installs the macOS app and its `mk` command.

## Install a tool

| Tool | Install |
| --- | --- |
| [Agent Guard](https://github.com/Entwining/agent-guard) | `brew install entwining/tap/agent-guard` |
| [Maskey](https://github.com/Entwining/maskey) | `brew install --cask entwining/tap/maskey` |
| [Rexume](https://github.com/Entwining/rexume) | `brew install entwining/tap/rexume` |
| [Sessidx](https://github.com/Entwining/sessidx) | `brew install entwining/tap/sessidx` |

## Upstream contract

This tap owns the Homebrew formulae, bottles, and casks. The [upstream contract](docs/maintenance.md#upstream-contract) defines release notifications and the `make build` interface.

Follow the [maintenance guide](docs/maintenance.md) to publish releases, recover failed publication, add formulae, update workflow dependencies, configure repository settings, and run checks.
