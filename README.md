# Lutest

Lutest is a test runner for Luau code, with a focus on `lute` and Roblox runtimes.

Key ideas:

- test kind and runtime should stay separate
- tests should be able to live close to the module under test
- internal or non-exported behavior should still be testable
- public-only APIs or dependency injection should not be required just to make testing possible

That is closer to how tests are commonly written in [Rust](https://rust-lang.org/) projects.

For Roblox specifically, the long-term plan is integration with [Roblox Open Cloud Luau Execution](https://create.roblox.com/docs/cloud/reference/features/luau-execution), using Luau session tasks to run tests in a headless Studio-style workflow for development and CI.

## Scope

Lutest should cover:

- unit tests
- integration tests
- conformance tests
- end-to-end tests

The project is not intended to treat one of these as the only correct way to test Luau code.

## Runtimes

Current runtime targets:

- `lute`
- Roblox runtimes

Direct support for running suites on the standalone `luau` CLI is not a project goal right now. Local execution should go through the `lute` runtime.

It should also be possible to run the same test suite across different Luau-oriented runtimes when that is useful.

## Status

- Lutest will remain under constant change while the project is still in its early stages.
- Expect experimental work, and do not treat releases as final or stable yet.
- Breaking changes may happen in any release for now.

## Setup

Install the pinned tools with:

```powershell
mise install
```

## Configuration

Lutest can read a `lutest.toml` file from the project root.

Currently supported keys:

```toml
[discovery]
require = "@lib"
roots = ["."]
ignore = ["vendor", "luau_packages", ".git"]
gitignore = true
```

- `require`: module path used to identify test-bearing modules during discovery
- `roots`: directories or files used when the CLI runs without explicit paths
- `ignore`: additional paths pruned during discovery
- `gitignore`: whether discovery should also respect `.gitignore`

## License

Lutest is distributed under the terms of the [MIT License](LICENSE).
