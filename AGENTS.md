Avoid editing `vendor` directly.

That directory should be treated as read-only for normal project work and exists mainly for reference, study, and source inspection.

Keep an eye on `vendor/luau-lsp/src/Plugin/README.md` as a reference for source transformation, plugin-based workflows, and future co-located test authoring support.

Treat the Luau LSP plugin system as a tooling and editor-workflow reference, not as the core architecture of `lutest`.

Do not add `--!strict` headers to project Luau files unless a specific file genuinely needs an explicit override; the project manifest already enforces strict mode.

Do not introduce metatables unless the user explicitly asks for them or they are genuinely necessary and the user has approved that specific use first.
