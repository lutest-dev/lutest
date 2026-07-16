# lutest

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
