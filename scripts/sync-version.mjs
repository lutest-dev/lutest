import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = process.cwd();
const packagePath = resolve(root, 'package.json');
const packageJson = JSON.parse(await readFile(packagePath, 'utf8'));
const version = packageJson.version;
const semver = /\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?/;

if (typeof version !== 'string' || !semver.test(version)) {
  throw new Error(`package.json has an invalid version: ${String(version)}`);
}

async function updateFile(path, replacements) {
  const source = await readFile(path, 'utf8');
  let output = source;

  for (const [pattern, replacement] of replacements) {
    if (!pattern.test(output)) {
      throw new Error(`Could not update version in ${path}`);
    }

    output = output.replace(pattern, replacement);
  }

  await writeFile(path, output);
}

await updateFile(resolve(root, 'core/version.luau'), [
  [/const VALUE = '[^']+'/, `const VALUE = '${version}'`],
]);

await updateFile(resolve(root, 'cli/version.luau'), [
  [
    /assert\(format_version\(\) == 'lutest [^']+'\)/,
    `assert(format_version() == 'lutest ${version}')`,
  ],
]);

await updateFile(resolve(root, 'mise.toml'), [
  [
    /"github:lutest-dev\/lutest" = "[^"]+"/,
    `"github:lutest-dev/lutest" = "${version}"`,
  ],
]);

await updateFile(resolve(root, 'wally.toml'), [
  [/version = "[^"]+"/, `version = "${version}"`],
]);

await updateFile(resolve(root, 'loom.config.luau'), [
  [/version = '[^']+'/, `version = '${version}'`],
  [/rev = 'v[^']+'/, `rev = 'v${version}'`],
]);

await updateFile(resolve(root, 'loom.lock.luau'), [
  [/lutest@v[^']+'/g, `lutest@v${version}'`],
  [/Packages\/lutest@v[^']+'/g, `Packages/lutest@v${version}'`],
  [/rev = 'v[^']+'/, `rev = 'v${version}'`],
]);

await updateFile(resolve(root, '.config.luau'), [
  [
    /lutest_release = 'Packages\/lutest@v[^']+\/lib'/,
    `lutest_release = 'Packages/lutest@v${version}/lib'`,
  ],
]);
