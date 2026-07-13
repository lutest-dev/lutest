Lutest [![CI](https://github.com/lutest-dev/lutest/actions/workflows/ci.yml/badge.svg)](https://github.com/lutest-dev/lutest/actions/workflows/ci.yml)
====

Lutest is a test runner for Luau modules, with local Lute and remote Roblox
runtimes.

It lets modules remain normal Luau modules while tests can live next to the
code they exercise.

[Documentation](https://lutest-dev.github.io/site/) ·
[Contributing](CONTRIBUTING.md) ·
[Releases](https://github.com/lutest-dev/lutest/releases)

# Runtimes

- **Lute** runs tests locally.
- **Roblox** runs tests remotely through
  [Open Cloud Luau Execution](https://create.roblox.com/docs/cloud/reference/features/luau-execution).

# Repository

This repository contains the Lutest CLI, test library, and runtime
implementations. For installation, configuration, usage, and Roblox setup,
see the [documentation](https://lutest-dev.github.io/site/).

# Status

Lutest is ready for production use. Its public API and configuration are still
evolving, so upgrades may include breaking changes.

# License

Lutest is distributed under the terms of the [MIT License](LICENSE).
