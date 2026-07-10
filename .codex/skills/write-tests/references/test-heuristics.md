# Test Heuristics

Use this reference when the right test is not obvious or when a draft feels low-value.

## Pick These First

- Regressions with a clear broken outcome.
- Inputs near edges: empty, missing, duplicate, invalid, out-of-order, or conflicting.
- Behavior that changes under flags, modes, focus rules, or config.
- User-facing diagnostics, especially messages that guide recovery.
- State transitions where a stale value, leak, or wrong reset would hurt later work.

## Usually Skip These

- Snapshot-like structure checks with no behavioral meaning.
- Tests that duplicate another case with only renamed literals.
- Deep mocking around simple pure logic.
- Coverage for dead-obvious pass-through code unless the surrounding contract is fragile.

## Name Compression

Turn this:

- `should return a skipped result for non-only tests when focus-only mode is active`

Into this:

- `should skip non-only tests under focus`

Turn this:

- `should produce an error message when the explicit path does not exist and a nearby path is found`

Into this:

- `should suggest a nearby explicit test path when available`

## Good Test Ideas By Pattern

- Parser: invalid token, ambiguous input, precedence edge, unknown command with suggestion.
- Discovery: duplicate paths, sorted output, ignored files, missing explicit path.
- Runner: registration order, focus filtering, todo preservation, error capture, state reset.
- Reporter: count aggregation, detail ordering, empty output, omission of irrelevant sections.

## Review Before Keeping

Ask:

1. What real mistake would this catch?
2. Would I keep this test if suite runtime doubled?
3. Is the name understandable without opening the body?
4. Did I assert behavior or just implementation shape?
