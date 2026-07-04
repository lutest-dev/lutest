Avoid editing `vendor` directly.

That directory should be treated as read-only for normal project work and exists mainly for reference, study, and source inspection.

Keep an eye on `vendor/luau-lsp/src/Plugin/README.md` as a reference for source transformation, plugin-based workflows, and future co-located test authoring support.

Treat the Luau LSP plugin system as a tooling and editor-workflow reference, not as the core architecture of `lutest`.

Do not add `--!strict` headers to project Luau files unless a specific file genuinely needs an explicit override; the project manifest already enforces strict mode.

Prefer low-nesting code. Flatten control flow aggressively with early returns, small helpers, and extracted fixtures when that keeps behavior unchanged. Avoid deeply nested conditionals, loops, and test fixtures unless there is a clear payoff.

Never delete tests. If deleting or replacing a test appears advisable, stop and tell the user first instead of removing it unilaterally.

Treat Lutest as self-hosted through the stable release locked by the local toolchain: the Lutest CLI installed via `mise` and the Lutest package installed via `loom`. Do not assume the current source tree must literally execute itself as its own stable runner, and do not classify odd behavior in `lute run cli/init.luau .` as a product bug by default when it comes from mixing the current source tree with that locked release-host model.

Do not introduce metatables unless the user explicitly asks for them or they are genuinely necessary and the user has approved that specific use first.

Do not make project scripts depend on the internal checkout layout of `vendor` or on uninitialized submodules unless the script is explicitly maintainer-only and that constraint is documented in the script and user-facing docs.

Prefer external tools to be resolved from the environment, explicit arguments, or dedicated env vars over hardcoded paths inside `vendor`.
