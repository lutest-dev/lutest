Treat `vendor` as read-only. Do not edit it during normal project work.

Use `vendor/luau-lsp/src/Plugin/README.md` only as a tooling and editor-workflow reference, especially for source transformation and future co-located test authoring ideas. Do not treat the Luau LSP plugin system as core `lutest` architecture.

Do not add `--!strict` headers unless a file genuinely needs an explicit override; the project manifest already enforces strict mode.

Prefer low-nesting code. Flatten control flow with early returns, small helpers, and extracted fixtures when behavior stays clear. Avoid deep conditionals, loops, and nested test setup unless they pay for themselves.

When evaluating a release candidate, do not reject the new binary solely because it is incompatible with a previous test-registration contract if that break is intentional. Smoke tests must validate the contract of the release being prepared, not silently reimpose legacy compatibility as a hidden release gate.

Do not introduce metatables unless the user explicitly asks for them or has approved that specific use first.

Never use `_G` for runtime state, feature flags, dependency injection, or communication between modules. Pass state explicitly through function arguments or use a scoped module-level abstraction instead.

Do not make project scripts depend on `vendor` checkout layout or uninitialized submodules unless the script is explicitly maintainer-only and that constraint is documented in the script and user-facing docs.

Prefer external tools resolved from the environment, explicit arguments, or dedicated env vars over hardcoded paths inside `vendor`.

## Pull requests and releases

Work on a `type/slug` branch and merge changes through a pull request. Do not
commit or push directly to `main` unless the user explicitly overrides this
rule.

After pushing a work branch, open its pull request as a draft by default. The
user decides when it is ready for review and merge. Before asking that
decision, report concise reasons to accept the pull request and any concrete
reasons not to accept it yet, including unverified risks or failing checks.
Pull request titles must follow Conventional Commits. When a pull request
resolves an issue, include `Close #<issue-number>` in its description.

When reporting a newly opened pull request to the user, format the merge
recommendation clearly with separate reasons to accept and reasons not to
accept. Base both sections on an actual review of the diff and verification
results, never intuition. Include only concrete risks, failing checks, or
unverified behavior in the reasons not to accept. Report this recommendation
and validation results in the chat, not in the pull request description. Keep
the pull request description focused on the change summary and rationale.

When the user asks to commit, determine whether the change belongs to the
purpose of the current branch and its pull request. Commit and push it to that
pull request only when the responsibility matches. Otherwise create a new
`type/slug` branch and a separate draft pull request; do not mix unrelated
work merely because a branch is already active.

Every pull request requires exactly one release decision. This is a mandatory
merge gate, not an optional follow-up. Decide it before opening the pull
request, then verify that the corresponding metadata is present before
reporting the pull request to the user:

- For a user-visible change that belongs in a release, create a Changeset with
  the appropriate SemVer bump before pushing the branch.
- For a change with no release impact, such as an internal refactor, CI, test,
  documentation, or tooling change, apply the `no-release` label immediately
  after opening the draft pull request.
- Never leave a pull request without a Changeset or the `no-release` label.
  Do not ask the user to review or merge it until this is verified.
- Ask the user only when the release impact or the SemVer bump is genuinely
  ambiguous.

Changesets accumulate after merge and the Release PR is generated or updated by
automation. Do not manually create or edit a Release PR unless the user asks.
Merging a regular pull request does not publish a release. Merging the
automated Release PR publishes the validated Windows, Linux, and macOS ARM64
assets, creates the version tag, and creates the GitHub Release.
