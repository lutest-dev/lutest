---
name: lutest-release
description: Publish Lutest releases safely for this repository. Use when the user asks to build, test, tag, or publish a new Lutest version, create a GitHub release, or make the release consumable by mise. This skill covers version bumps, release asset naming, smoke-testing the built binary before upload, and reporting any failure instead of publishing a broken release.
---

# Lutest Release

Use the repository release scripts where they are reliable, and do the publish steps manually.

## Workflow

1. Confirm the target version and inspect the current working tree.
2. Bump the versioned files manually:
   - `package.json`
   - `mise.toml`
   - `loom.config.luau`
   - `loom.lock.luau`
   - `docs/src/content/docs/installation.md`
   - `docs/src/content/docs/pt-br/installation.md`
3. Build the release binary with `scripts/release.luau`.
4. Ensure the release asset uses the platform-aware name expected by `mise`, such as `lutest-v0.1.4-windows-x64.exe`.
5. Smoke-test the built asset before any tag or GitHub release upload.
6. Commit the version bump with `--no-verify` when necessary, then push `main`.
7. Create and push the annotated tag.
8. Create the GitHub release and upload the tested asset.
9. When a release already exists and another OS or architecture needs to contribute its own binary, build that asset locally, smoke-test it, and upload it with `gh release upload --clobber`.
10. If any build, smoke test, tag, push, or upload step fails, stop and report the problem to the user instead of partially publishing.

## Commands

Use these commands from the repository root:

```sh
lute run scripts/release.luau cli/init.luau .tmp/release-bundle/main.luau dist/lutest-v<version>-<platform>-<arch>[.exe]
git commit --no-verify -m "chore(release): v<version>"
git tag -a v<version> -m v<version>
gh release create v<version> dist/lutest-v<version>-<platform>-<arch>[.exe] --title v<version> --generate-notes
gh release upload v<version> dist/lutest-v<version>-<platform>-<arch>[.exe] --clobber
```

Use `scripts/release.luau` for the build step in the manual release flow.
Use `gh release upload --clobber` when a release already exists and another OS or architecture needs to attach its own asset.

## Required Checks

- Keep the git worktree clean before publishing.
- Verify the target tag and GitHub release do not already exist.
- Update the versioned files intentionally and review the diff before committing.
- Smoke-test the generated asset locally before upload.

The minimum smoke test is the repository's current release check:

```sh
./dist/lutest-v<version>-<platform>-<arch> core/runner.luau
```

Treat a passing smoke test as mandatory. Do not upload an untested asset.

## Repository-Specific Notes

- `scripts/release.luau` is the build step.
- `mise` compatibility depends on the uploaded asset name matching the expected platform and architecture pattern.
- Release publishing is manual on purpose. The repository no longer keeps a publish orchestrator script because the edge cases were not worth encoding in project code.
- Use `git commit --no-verify` for the release commit when bumping `mise.toml` to an unreleased Lutest version would break local hooks that call `mise exec`.

## Failure Handling

If the release flow encounters any issue, report:

- which step failed
- the relevant command
- whether anything was already pushed, tagged, or uploaded

Do not continue past a failed smoke test, and do not create or keep a misleading release in that state.
