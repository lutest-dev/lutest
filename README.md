<div align="center">

<h1 align="center">
  <img src="https://raw.githubusercontent.com/lutest-dev/site/main/assets/logo.png" alt="" width="56" height="56" align="absbottom" />
  Lutest
</h1>

<p align="center"><strong>A modern test runner for Luau projects.</strong></p>

Keep tests next to the modules they exercise. Run them locally with Lute or
against Roblox through Open Cloud Luau Execution.

[![CI](https://github.com/lutest-dev/lutest/actions/workflows/ci.yml/badge.svg)](https://github.com/lutest-dev/lutest/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/lutest-dev/lutest?display_name=tag&sort=semver)](https://github.com/lutest-dev/lutest/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[Documentation](https://lutest-dev.github.io/site/) ·
[Releases](https://github.com/lutest-dev/lutest/releases) ·
[Contributing](CONTRIBUTING.md)

</div>

## At a glance

Lutest discovers modules that require the configured Lutest package, loads each
module as an implicit test suite, and runs its registered tests. Test modules
remain ordinary Luau modules: they do not need to return suite objects, follow a
mandatory filename convention, or use a separate assertion DSL.

- **Co-located authoring.** Keep tests next to the code they exercise. The
  configured `require` path, not a `.test.luau` or `.spec.luau` suffix, defines
  discovery.
- **Local and Roblox runtimes.** Run local tests with
  [Lute](https://github.com/luau-lang/lute), or execute Roblox-dependent tests
  through
  [Open Cloud Luau Execution](https://create.roblox.com/docs/cloud/reference/features/luau-execution).
- **Explicit structure.** Use suites and lifecycle hooks when shared setup is
  useful, and mark tests as `skip`, `only`, or `todo` when appropriate.
- **Debuggable workflow.** Inspect discovery and Roblox bundles before running
  remote tests, and validate the project environment with built-in diagnostics.

## Documentation

The [documentation site](https://lutest-dev.github.io/site/) contains the
installation guide, first test, test-writing model, configuration reference,
runtime guides, and CLI/API references.

For the current binaries and release notes, see
[GitHub Releases](https://github.com/lutest-dev/lutest/releases).

## Project status

The public API and configuration are still evolving. Pin a specific release
when coordinating upgrades with your project.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, validation
commands, and contribution guidelines.

## License

Lutest is distributed under the [MIT License](LICENSE).
