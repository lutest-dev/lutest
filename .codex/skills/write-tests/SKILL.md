---
name: write-tests
description: Write or revise tests with high signal and clear intent. Use when Codex needs to add coverage, close a regression gap, review whether a proposed test is worth keeping, or reshape weak tests into short behavior-focused cases with `should*` names, realistic scenarios, and minimal noise.
---

# Write Tests

Write tests that defend real behavior, not implementation trivia.

Prefer the smallest test set that would catch a meaningful break.

## Workflow

1. Read the changed code and the nearby tests before writing anything.
2. Identify the user-visible contract, bug risk, or regression surface.
3. Choose only tests that would fail for a meaningful mistake.
4. Name each test with a short `should*` statement.
5. Keep setup tight, assertions specific, and fixtures realistic.
6. Run the narrowest relevant test command first, then broader validation if needed.

## Choose High-Value Tests

Prefer tests that cover one of these:

- A bug that already happened or is likely from the code path.
- Branching behavior with different outcomes.
- Boundary conditions, empty inputs, missing config, or invalid arguments.
- Error messages or diagnostics the user will read.
- Ordering rules, deduplication, filtering, fallback logic, or state transitions.
- Integration between modules when the seam is easy to break.

Avoid tests that only prove:

- A helper returns fields exactly as written in the fixture with no meaningful transformation.
- A mocked path calls the same mock you just configured.
- An internal temporary shape exists unless that shape is the public contract.
- A line of code ran, without asserting the behavior that matters.

When torn between two tests, keep the one that would be more useful in a real regression.

## Test Naming

Use short names starting with `should`.

Rules:

- State the behavior, not the implementation.
- Keep one idea per test name.
- Prefer concrete outcomes over vague verbs like `work`, `handle`, or `behave`.
- Omit filler words unless they disambiguate the case.

Good:

- `should reject help flags`
- `should preserve result order`
- `should ignore register without active module`
- `should suggest a nearby explicit test path when available`

Bad:

- `should work`
- `should test command parser`
- `should call helper`
- `should do the right thing`

## Writing Style

- Prefer one clear assertion cluster per test.
- Use realistic inputs that explain why the case exists.
- Keep fixture size proportional to the behavior under test.
- Flatten setup; extract helpers only when repetition is real.
- Assert the most user-relevant artifact first: result, error, order, emitted text, or state transition.
- Do not add comments unless the setup would otherwise be hard to parse.

## Repository Notes

- Follow existing local test style, especially `t.test(...)` patterns already present in nearby files.
- Prefer extending existing coverage near the changed code over inventing detached fixture files.
- Preserve the project's current terminology in test names and assertions.
- Treat Lutest as self-hosted through the stable release locked by the local toolchain: the CLI installed via `mise` and the package installed via `loom`. Do not assume the current source tree must behave as its own stable runner.
- Do not delete tests unless the user explicitly asks. If deleting or replacing a test seems advisable, stop and tell the user first.
- Do not hardcode source-tree modules, bootstrap helpers, or special-case source paths into the stable runner just to accommodate current-source execution. If that seems necessary, stop and ask first.

## Running Tests In This Repo

Prefer the stable `lutest` CLI from the toolchain when validating behavior.

Primary commands:

```powershell
lutest test
lutest test .
lutest test src
lutest test src packages
```

Use path-targeted runs whenever a smaller scope is enough.

Useful companion commands:

```powershell
lutest todo
lutest todo src
lutest help
lutest version
mise run check
mise run lint
mise run typecheck
```

Interpretation rules:

- Prefer `lutest test ...` when judging whether a change is acceptable.
- Do not treat odd behavior in `lute run cli/init.luau .` as a product bug by default.
- Do not change architecture, bootstrap flow, or runner responsibilities just to make `lute run cli/init.luau .` behave like a first-class path unless the user explicitly asks.
- When `lutest test` runs with no explicit paths, it uses `roots` from `lutest.toml`, or `.` when no config is present.
- Exit `0` means all discovered tests passed. Exit `1` means discovery found nothing or at least one test failed.

## Validation

After writing tests:

1. Run the narrowest relevant `lutest test ...` target first.
2. If the change affects CLI text, discovery, or reporting, prefer a real command path over a pure unit-only check when practical.
3. Confirm the test fails for the intended broken behavior when practical.
4. Confirm the final passing state without broad unrelated changes.
5. Re-read the test names and cut any word that does not help the reader.

Read [references/test-heuristics.md](references/test-heuristics.md) when choosing between candidate tests or when a draft still feels generic.
