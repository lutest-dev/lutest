# Errors TODO

## Assertion Failure vs Runtime Error inside a Test Case

- Error found: the runner currently captures failed test execution as a raw error message string.
- Why this is ambiguous: plain `assert(...)` failures and arbitrary runtime exceptions both arrive through the same path, so the framework cannot reliably distinguish an assertion failure from a general runtime error without a stronger error contract.
- Design suggestion: introduce a structured failure object or a dedicated assertion helper that tags assertion failures explicitly before the reporter formats them.

## Direct Unit Coverage for Top-Level CLI and Release Scripts

- Error found: `cli/init.luau`, `scripts/release.luau`, and `scripts/deploy-docs.luau` still execute side effects at module load time.
- Why this is ambiguous: testing their error handling directly would require either process-level integration tests or new seams for injected process/filesystem behavior.
- Design suggestion: extract pure command execution helpers from the top-level scripts so user-facing error formatting can be unit-tested without invoking real process exits or git operations.
