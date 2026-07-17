# lutest

## 0.7.0

### Minor Changes

- [#54](https://github.com/lutest-dev/lutest/pull/54) [`6c2be75`](https://github.com/lutest-dev/lutest/commit/6c2be750f0fe9d366c1f9c418f21eb83351d45f4) Thanks [@cayasde](https://github.com/cayasde)! - Keep test definitions inert when Lutest is not collecting a test suite.

- [#61](https://github.com/lutest-dev/lutest/pull/61) [`cd9a203`](https://github.com/lutest-dev/lutest/commit/cd9a20361177c1e05c145da8d19d141b097c69e4) Thanks [@cayasde](https://github.com/cayasde)! - Add `lutest debug bundle` to inspect the Roblox test bundle layout without uploading or running tests.

- [#57](https://github.com/lutest-dev/lutest/pull/57) [`befb942`](https://github.com/lutest-dev/lutest/commit/befb9428f6697f3537edf2b30f7151c50af4c1fa) Thanks [@cayasde](https://github.com/cayasde)! - Expose `t.is_running()` to detect active Lutest sessions.

- [#53](https://github.com/lutest-dev/lutest/pull/53) [`da338c1`](https://github.com/lutest-dev/lutest/commit/da338c1f30c1b6640c63a0a101a07927fdb7eb64) Thanks [@cayasde](https://github.com/cayasde)! - Warn when a discovered test suite registers no tests.

### Patch Changes

- [#62](https://github.com/lutest-dev/lutest/pull/62) [`74bd336`](https://github.com/lutest-dev/lutest/commit/74bd336a1b8df0c9382db470bba798366a3cf7a6) Thanks [@cayasde](https://github.com/cayasde)! - Present CLI help as a grouped command reference.

- [#59](https://github.com/lutest-dev/lutest/pull/59) [`e08e178`](https://github.com/lutest-dev/lutest/commit/e08e1781a1debf3921230040b1ad731aa906301e) Thanks [@cayasde](https://github.com/cayasde)! - Publish a `Lib.rbxm` Roblox library asset alongside each GitHub Release.

- [#56](https://github.com/lutest-dev/lutest/pull/56) [`6e18d10`](https://github.com/lutest-dev/lutest/commit/6e18d10fcf2e8efd483a6dc4a432491196d128f5) Thanks [@cayasde](https://github.com/cayasde)! - Preserve original suite load errors and tracebacks from Roblox test runs.

- [#51](https://github.com/lutest-dev/lutest/pull/51) [`b3da779`](https://github.com/lutest-dev/lutest/commit/b3da779e63de607854c84461ed6beb450878ae32) Thanks [@cayasde](https://github.com/cayasde)! - Add editor documentation for the public Lutest library API.

- [#55](https://github.com/lutest-dev/lutest/pull/55) [`9653e9a`](https://github.com/lutest-dev/lutest/commit/9653e9a07df80988bf83fd5e1261b4f44022ad5e) Thanks [@cayasde](https://github.com/cayasde)! - Discover Roblox test suites from Luau syntax instead of source text.

- [#58](https://github.com/lutest-dev/lutest/pull/58) [`187e268`](https://github.com/lutest-dev/lutest/commit/187e2686d89102b2cb0b7e2a29733588605d908a) Thanks [@cayasde](https://github.com/cayasde)! - Validate the generated Wally package with a Roblox consumer before publication.

## 0.6.1

### Patch Changes

- [#36](https://github.com/lutest-dev/lutest/pull/36) [`00958e3`](https://github.com/lutest-dev/lutest/commit/00958e345ea2ba11c70baab0a485483f5749c480) Thanks [@cayasde](https://github.com/cayasde)! - Fix the Wally package entrypoint and preserve its public API during publication.

## 0.6.0

### Minor Changes

- [#27](https://github.com/lutest-dev/lutest/pull/27) [`56d68b1`](https://github.com/lutest-dev/lutest/commit/56d68b1eb063f23414d394e32d27f762e98ec69a) Thanks [@cayasde](https://github.com/cayasde)! - Remove the deprecated `install-package` command. Install the Roblox test library through Wally instead.

- [#25](https://github.com/lutest-dev/lutest/pull/25) [`70e503c`](https://github.com/lutest-dev/lutest/commit/70e503c65946b35d5109a0b4bcfa6f08717b0c9a) Thanks [@cayasde](https://github.com/cayasde)! - Publish the Roblox test library as a Wally package.

### Patch Changes

- [#32](https://github.com/lutest-dev/lutest/pull/32) [`60dcf03`](https://github.com/lutest-dev/lutest/commit/60dcf03d599ccd0d4bc982f29af9406a9472b856) Thanks [@cayasde](https://github.com/cayasde)! - Resolve configured discovery roots from the directory containing an explicit config file.

- [#30](https://github.com/lutest-dev/lutest/pull/30) [`c8f8b0d`](https://github.com/lutest-dev/lutest/commit/c8f8b0d73435b2358e139adf9057a8f4b5c1f975) Thanks [@cayasde](https://github.com/cayasde)! - Report syntax errors in candidate test files during discovery.

- [#31](https://github.com/lutest-dev/lutest/pull/31) [`9aafa07`](https://github.com/lutest-dev/lutest/commit/9aafa07ba2e870b8671da68a0650e0b36974b871) Thanks [@cayasde](https://github.com/cayasde)! - Report configured discovery roots that do not exist in `lutest doctor`.

- [#28](https://github.com/lutest-dev/lutest/pull/28) [`e436a41`](https://github.com/lutest-dev/lutest/commit/e436a41427b21b208815f7b7d2af1bf07520e678) Thanks [@cayasde](https://github.com/cayasde)! - Show versioned, numbered Roblox progress lines outside a TTY.

## 0.5.0

### Minor Changes

- [#17](https://github.com/lutest-dev/lutest/pull/17) [`f97cbd2`](https://github.com/lutest-dev/lutest/commit/f97cbd241e6a1f2677367531f40f8fc9bb595fe8) Thanks [@cayasde](https://github.com/cayasde)! - Add a `--config <path>` option to the test and todo commands.

- [#19](https://github.com/lutest-dev/lutest/pull/19) [`a9a6037`](https://github.com/lutest-dev/lutest/commit/a9a60371a120767a59e0014fb08bc78ab2a86fe8) Thanks [@cayasde](https://github.com/cayasde)! - Add a doctor command for local Lutest runtime diagnostics.

- [#18](https://github.com/lutest-dev/lutest/pull/18) [`5f7e89f`](https://github.com/lutest-dev/lutest/commit/5f7e89f5e85c22ed5043919290570a960fc14826) Thanks [@cayasde](https://github.com/cayasde)! - Add a dry-run option for test and todo discovery.

- [#13](https://github.com/lutest-dev/lutest/pull/13) [`e1b4e1b`](https://github.com/lutest-dev/lutest/commit/e1b4e1baa0ad5eb0d0634ab37ece783a5e74bca8) Thanks [@cayasde](https://github.com/cayasde)! - Add explicit test suites and lifecycle hooks for Lute and Roblox runtimes.
