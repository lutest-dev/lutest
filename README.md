# Lutest

Lutest is a test runner for Luau code, with a focus on `lute` and Roblox runtimes.

Key ideas:

- test kind and runtime should stay separate
- tests should be able to live close to the module under test
- internal or non-exported behavior should still be testable
- public-only APIs or dependency injection should not be required just to make testing possible

That is closer to how tests are commonly written in [Rust](https://rust-lang.org/) projects.

For Roblox projects, Lutest can run suites through [Roblox Open Cloud Luau Execution](https://create.roblox.com/docs/cloud/reference/features/luau-execution), using a session task against a configured place.

Roblox projects normally install the `lutest` library in the place for development and editor support. During a remote run, Lutest bundles the CLI's version of that library and overlays it at the configured Roblox require path inside the session task.

## Status

- Lutest will remain under constant change while the project is still in its early stages.
- Expect experimental work, and do not treat releases as final or stable yet.
- Breaking changes may happen in any release for now.

## License

Lutest is distributed under the terms of the [MIT License](LICENSE).
