import { readFile } from 'node:fs/promises'

const bumpRank = {
  patch: 1,
  minor: 2,
  major: 3,
}

export function createReleaseTitle(releases, packageName = 'lutest') {
  const packageReleases = releases.filter((release) => release.name === packageName)

  if (packageReleases.length === 0) {
    return 'chore(release): prepare next release'
  }

  const release = packageReleases.reduce((highest, current) => {
    if (bumpRank[current.type] > bumpRank[highest.type]) {
      return current
    }

    return highest
  })

  return `chore(release): prepare v${release.newVersion} (${release.type})`
}

async function main() {
  const [releasePlanPath] = process.argv.slice(2)

  if (!releasePlanPath) {
    throw new Error('Expected a Changesets release plan path.')
  }

  const releasePlan = JSON.parse(await readFile(releasePlanPath, 'utf8'))
  const title = createReleaseTitle(releasePlan.releases ?? [])

  console.log(`title=${title}`)
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main()
}
