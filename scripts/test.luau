const process = require '@std/process'
const system = require '@std/system'

const binary_path = if system.win32 then 'dist/lutest.exe' else 'dist/lutest'

const build = process.run {
	'lute',
	'run',
	'scripts/release.luau',
}
if build.exitcode ~= 0 then process.exit(build.exitcode) end

const test = process.run { binary_path, 'test' }
process.exit(test.exitcode)
