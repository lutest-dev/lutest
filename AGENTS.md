Treat `vendor` as read-only. Do not edit it during normal project work.

Use `vendor/luau-lsp/src/Plugin/README.md` only as a tooling and editor-workflow reference, especially for source transformation and future co-located test authoring ideas. Do not treat the Luau LSP plugin system as core `lutest` architecture.

Do not add `--!strict` headers unless a file genuinely needs an explicit override; the project manifest already enforces strict mode.

Prefer low-nesting code. Flatten control flow with early returns, small helpers, and extracted fixtures when behavior stays clear. Avoid deep conditionals, loops, and nested test setup unless they pay for themselves.

When evaluating a release candidate, do not reject the new binary solely because it is incompatible with a previous test-registration contract if that break is intentional. Smoke tests must validate the contract of the release being prepared, not silently reimpose legacy compatibility as a hidden release gate.

Do not introduce metatables unless the user explicitly asks for them or has approved that specific use first.

Never use `_G` for runtime state, feature flags, dependency injection, or communication between modules. Pass state explicitly through function arguments or use a scoped module-level abstraction instead.

Do not make project scripts depend on `vendor` checkout layout or uninitialized submodules unless the script is explicitly maintainer-only and that constraint is documented in the script and user-facing docs.

Prefer external tools resolved from the environment, explicit arguments, or dedicated env vars over hardcoded paths inside `vendor`.
