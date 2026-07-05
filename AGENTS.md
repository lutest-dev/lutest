Treat `vendor` as read-only. Do not edit it during normal project work.

Use `vendor/luau-lsp/src/Plugin/README.md` only as a tooling and editor-workflow reference, especially for source transformation and future co-located test authoring ideas. Do not treat the Luau LSP plugin system as core `lutest` architecture.

Do not add `--!strict` headers unless a file genuinely needs an explicit override; the project manifest already enforces strict mode.

Prefer low-nesting code. Flatten control flow with early returns, small helpers, and extracted fixtures when behavior stays clear. Avoid deep conditionals, loops, and nested test setup unless they pay for themselves.

Never delete tests. If deleting or replacing a test seems advisable, stop and tell the user first.

Treat Lutest as self-hosted through the stable release locked by the local toolchain: the CLI installed via `mise` and the package installed via `loom`. The current source tree does not need to behave as its own stable runner.

Prioritize `lutest .` over `lute run cli/init.luau .` when judging whether a change is acceptable. Do not classify odd behavior in `lute run cli/init.luau .` as a product bug by default, and do not change architecture, bootstrap flow, or runner responsibilities just to make that path behave like a first-class supported flow unless the user explicitly asks for it.

Do not hardcode source-tree modules, bootstrap helpers, or special-case source paths into the stable runner to accommodate current-source execution. If that seems necessary, stop and ask first.

Do not introduce metatables unless the user explicitly asks for them or has approved that specific use first.

Do not make project scripts depend on `vendor` checkout layout or uninitialized submodules unless the script is explicitly maintainer-only and that constraint is documented in the script and user-facing docs.

Prefer external tools resolved from the environment, explicit arguments, or dedicated env vars over hardcoded paths inside `vendor`.
