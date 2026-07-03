const fs = require '@std/fs'
const process = require '@std/process'
const path_utils = require '@lutest/utils/path'
const system = require '@std/system'

const DEFAULT_ENTRY = 'cli/init.luau'
const DEFAULT_BUNDLE_OUTPUT = 'dist/release-bundle/main.luau'
const DEFAULT_SMOKE_TEST = 'core/runner.luau'

const function run(args: { string }, cwd: string)
	const result = process.run(args, {
		cwd = cwd,
		stdio = 'inherit',
	})

	if result.exitcode == 0 then return end
	process.exit(result.exitcode)
end

const function validate_version(version: string)
	if string.match(version, '^%d+%.%d+%.%d+$') then return end
	error(`invalid version '{version}' (expected x.y.z)`, 0)
end

const function detect_platform(): string
	if system.win32 then return 'windows' end
	if system.macos then return 'macos' end
	if system.linux then return 'linux' end

	return string.lower(system.os)
end

const function detect_arch(): string
	const arch = string.lower(system.arch)
	if arch == 'x86_64' or arch == 'amd64' then return 'x64' end
	if arch == 'aarch64' then return 'arm64' end
	return arch
end

const function release_binary_path(cwd: string, version: string): string
	const extension = if system.win32 then '.exe' else ''
	const filename =
		`lutest-v{version}-{detect_platform()}-{detect_arch()}{extension}`
	return path_utils.resolve_path(cwd, `dist/{filename}`)
end

const function ensure_release_exists(version: string, cwd: string)
	const result = process.run({
		'gh',
		'release',
		'view',
		`v{version}`,
	}, {
		cwd = cwd,
	})

	if result.exitcode == 0 then return end
	error(`GitHub release 'v{version}' does not exist`, 0)
end

const function upload_release_asset(version: string, cwd: string)
	validate_version(version)
	ensure_release_exists(version, cwd)

	const binary_path = release_binary_path(cwd, version)
	run({
		'lute',
		'run',
		'scripts/release.luau',
		DEFAULT_ENTRY,
		DEFAULT_BUNDLE_OUTPUT,
		binary_path,
	}, cwd)

	if fs.exists(path_utils.resolve_path(cwd, DEFAULT_SMOKE_TEST)) then
		run({ binary_path, DEFAULT_SMOKE_TEST }, cwd)
	else
		run({ binary_path, '--help' }, cwd)
	end

	run({
		'gh',
		'release',
		'upload',
		`v{version}`,
		binary_path,
		'--clobber',
	}, cwd)

	print(`uploaded release asset for v{version}`)
end

const cwd = path_utils.normalize_path(process.cwd())
const version = process.args[2] or ''

if version == '' then
	error('usage: lute run scripts/upload-release-asset.luau <version>', 0)
end

upload_release_asset(version, cwd)
