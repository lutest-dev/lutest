---
name: lutest-release
description: Publish Lutest releases safely for this repository. Use when the user asks to build, test, tag, or publish a new Lutest version, create a GitHub release, or make the release consumable by mise. This skill covers version bumps, release asset naming, smoke-testing the built binary before upload, and reporting any failure instead of publishing a broken release.
---

# Lutest Release

Use the repository release scripts instead of improvising the flow.

## Workflow

1. Confirm the target version and inspect the current working tree.
2. Prefer `scripts/publish-release.luau` for the full release flow.
3. Ensure the release asset is built with the platform-aware name expected by `mise`, such as `lutest-v0.1.4-windows-x64.exe`.
4. Test the built asset before any tag or GitHub release upload.
5. If any build, smoke test, tag, push, or upload step fails, stop and report the problem to the user instead of partially publishing.

## Commands

Use these commands from the repository root:

```sh
lute run scripts/publish-release.luau <version> [remote]
pnpm release:publish -- <version>
```

Use `scripts/release.luau` only when the task is limited to building the bundle or binary without publishing.

## Required Checks

- Keep the git worktree clean before publishing.
- Verify the target tag and GitHub release do not already exist.
- Let `scripts/publish-release.luau` update the versioned files instead of editing them ad hoc.
- Smoke-test the generated asset locally before upload.

The minimum smoke test is the repository's current release check:

```sh
./dist/lutest-v<version>-<platform>-<arch> core/runner.luau
```

Treat a passing smoke test as mandatory. Do not upload an untested asset.

## Repository-Specific Notes

- `scripts/release.luau` is the build step.
- `scripts/publish-release.luau` is the publish orchestrator.
- `mise` compatibility depends on the uploaded asset name matching the expected platform and architecture pattern.
- The publish script intentionally uses `git commit --no-verify` because bumping `mise.toml` to an unreleased Lutest version can break local hooks that call `mise exec`.

## Failure Handling

If the release flow encounters any issue, report:

- which step failed
- the relevant command
- whether anything was already pushed, tagged, or uploaded

Do not continue past a failed smoke test, and do not create or keep a misleading release in that state.
