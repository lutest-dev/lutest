Avoid editing `vendor` directly.

That directory should be treated as read-only for normal project work and exists mainly for reference, study, and source inspection.

Keep an eye on `vendor/luau-lsp/src/Plugin/README.md` as a reference for source transformation, plugin-based workflows, and future co-located test authoring support.

Treat the Luau LSP plugin system as a tooling and editor-workflow reference, not as the core architecture of `lutest`.
