# Contributing to Lutest

Thanks for helping improve Lutest.

## Questions, bugs, and features

- Use [GitHub issues](https://github.com/lutest-dev/lutest/issues) for
  questions, bug reports, and design discussion. For reproducible bugs, include
  the Lutest version, operating system, command, expected result, actual result,
  and a minimal reproduction when possible.
- Discuss new user-facing features before implementing them. Small fixes and
  documentation improvements can be proposed directly in a pull request.

## Documentation

User documentation lives at [lutest-dev.github.io/site](https://lutest-dev.github.io/site/).
Keep installation, configuration, CLI usage, and Roblox setup there instead of
duplicating them in this repository. Documentation source lives in the
[site repository](https://github.com/lutest-dev/site).

## Development

Install the pinned tools and project dependencies:

```powershell
mise install
mise exec github:pesde-pkg/pesde@0.7.3+registry.0.2.3 `
  --command "pesde install"
pnpm install
```

Before opening a pull request, run:

```powershell
mise run check
lutest test
```

Run Roblox tests only when you have configured the required Open Cloud
credentials:

```powershell
lutest test game --runtime roblox
```

## Pull requests

- Keep each pull request focused on one responsibility.
- Follow the existing Luau style and keep control flow straightforward.
- Add focused coverage for behavior changes.
- Do not edit `vendor`.
- Add a Changeset for user-visible changes. For documentation, CI, tests, or
  internal-only changes, ask a maintainer to apply the `no-release` label.
- Make sure CI passes before requesting review.

By contributing, you agree that your contribution is licensed under the
[MIT License](LICENSE).
