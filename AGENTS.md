Avoid editing `vendor` directly.

That directory should be treated as read-only for normal project work and exists mainly for reference, study, and source inspection.

Keep an eye on `vendor/luau-lsp/src/Plugin/README.md` as a reference for source transformation, plugin-based workflows, and future co-located test authoring support.

Treat the Luau LSP plugin system as a tooling and editor-workflow reference, not as the core architecture of `lutest`.

Do not create or expand project `*.spec.luau` tests for now.

The project does not yet have its own stable test runner, so avoid introducing self-hosted tests or growing a project test suite at this stage.

Prefer evolving `core`, `runtimes`, contracts, and architecture first; only use ad hoc local experiments when strictly necessary, and do not formalize them as project specs yet.
