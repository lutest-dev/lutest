import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const tag = process.env.LUTEST_BOOTSTRAP_TAG;
const root = process.cwd();

if (!/^v\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/.test(tag ?? '')) {
  throw new Error(`LUTEST_BOOTSTRAP_TAG must be a version tag, received: ${String(tag)}`);
}

const replacements = [
  [
    'mise.toml',
    /"github:lutest-dev\/lutest" = "[^"]+"/,
    `"github:lutest-dev/lutest" = "${tag.slice(1)}"`,
  ],
  ['loom.config.luau', /rev = 'v[^']+'/, `rev = '${tag}'`],
  [
    '.config.luau',
    /lutest_release = 'Packages\/lutest@v[^']+\/lib'/,
    `lutest_release = 'Packages/lutest@${tag}/lib'`,
  ],
];

for (const [relativePath, pattern, replacement] of replacements) {
  const path = resolve(root, relativePath);
  const source = await readFile(path, 'utf8');

  if (!pattern.test(source)) {
    throw new Error(`Could not update ${relativePath} for release self-hosting.`);
  }

  await writeFile(path, source.replace(pattern, replacement));
}
