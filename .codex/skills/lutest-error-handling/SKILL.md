---
name: lutest-error-handling
description: Standardize user-facing error handling for Lutest with DX-first messages that stay honest about cause and ownership. Use when changing CLI errors, discovery/config errors, runner load errors, warnings, or reporter output, and when deciding whether an error is a UsageError, ConfigurationError, RuntimeError, Assertion failure, or InternalError.
---

# Lutest Error Handling

Keep Lutest errors clear for the user without hiding framework bugs.

## Terminology

Use these terms consistently:

- `test file`
- `test case`
- `test suite`
- `assertion`
- `runner`
- `config`
- `reporter`
- `hook`
- `matcher`

Do not switch between synonyms like "module" and "test file" in user-facing error messages unless the code path is explicitly about Lua module loading internals.

## Error Categories

Classify each error before changing its message:

- `UsageError`: the user passed a bad command, bad path, unsupported argument, or otherwise used the CLI/API incorrectly.
- `ConfigurationError`: `lutest.toml` or related config is invalid, missing required values, or points at nonexistent roots.
- `RuntimeError`: a `test file` or code loaded by the runner crashed while being loaded or prepared.
- `Assertion failure`: a `test case` failed because an assertion did not pass.
- `InternalError`: Lutest itself crashed or reached an impossible state.

If the code path cannot reliably distinguish `Assertion failure` from `RuntimeError`, do not fake certainty. Preserve the current behavior and add an item to `ERRORS_TODO.md`.

## Message Format

Prefer the shared formatter in `core/errors.luau`.

Use this structure:

```text
[lutest] Kind: short summary.

Where:
precise context

How to fix:
actionable next step

Details:
raw error or stack trace when useful
```

Rules:

- Make the first line understandable on its own.
- Add `Where:` when the failing command, `test file`, or config path is known.
- Add `How to fix:` only when the fix is justified by the real code path.
- Add `Details:` for raw parser errors, module load errors, or internal stack traces.
- Avoid vague summaries like "something went wrong", "invalid input", or "failed".

## Workflow

1. Read the current error flow end to end before editing.
2. Identify where the error is raised, where it is caught, and what text reaches the user.
3. Decide whether the error belongs to the user, the tested code, or Lutest itself.
4. Wrap or rethrow with shared formatting and explicit context.
5. Preserve raw stack traces for `RuntimeError` and `InternalError` when they help debugging.
6. Add or update tests for the exact error category and message shape you changed.
7. If the classification is ambiguous, document it in `ERRORS_TODO.md` instead of inventing semantics.

## Guardrails

- Do not swallow errors silently.
- Do not reword an internal bug as if it were the user's fault.
- Do not remove stack traces from internal/framework crashes.
- Do not change functional behavior just to make tests easier.
- Prefer narrow changes in `cli`, `runtimes/lute/config`, `runtimes/lute/discovery`, `runtimes/lute/runner`, and `core/reporter` before touching unrelated code.

## Validation

After changing error handling:

1. Run `lutest test`.
2. Reproduce at least one real CLI failure path when relevant, such as:
   - missing explicit `test file` path
   - invalid `lutest.toml`
   - crashing `test file`
3. Check that the output is clearer without hiding raw details that are still needed.
