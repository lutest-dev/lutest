const fs = require '@std/fs'
const process = require '@std/process'
const path_utils = require '@lutest/utils/path'
const system = require '@std/system'

const DEFAULT_ENTRY = 'cli/init.luau'
const DEFAULT_BUNDLE_OUTPUT = 'dist/release-bundle/main.luau'
const DEFAULT_REMOTE = 'origin'
const DEFAULT_SMOKE_TEST = 'core/runner.luau'

type Replacement = {
	path: string,
	needle: string,
	replacement: string,
}

const function run(args: { string }, cwd: string)
	const result = process.run(args, {
		cwd = cwd,
		stdio = 'inherit',
	})

	if result.exitcode == 0 then return end
	process.exit(result.exitcode)
end

const function run_capture(args: { string }, cwd: string): string
	const result = process.run(args, {
		cwd = cwd,
	})

	if result.exitcode ~= 0 then process.exit(result.exitcode) end
	return if type(result.stdout) == 'string' then result.stdout else ''
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

const function ensure_clean_repo(cwd: string)
	const status = string.gsub(
		run_capture({ 'git', 'status', '--short' }, cwd),
		'%s+$',
		''
	)
	if status == '' then return end

	error('git worktree must be clean before publishing a release', 0)
end

const function ensure_missing_tag(version: string, cwd: string)
	const existing = string.gsub(
		run_capture({ 'git', 'tag', '--list', `v{version}` }, cwd),
		'%s+$',
		''
	)
	if existing == '' then return end

	error(`git tag 'v{version}' already exists`, 0)
end

const function ensure_missing_release(version: string, cwd: string)
	const result = process.run({
		'gh',
		'release',
		'view',
		`v{version}`,
	}, {
		cwd = cwd,
	})

	if result.exitcode ~= 0 then return end
	error(`GitHub release 'v{version}' already exists`, 0)
end

const function read_current_version(cwd: string): string
	const package_json = fs.readFileToString(
		path_utils.resolve_path(cwd, 'package.json')
	)
	const version =
		string.match(package_json, '"version"%s*:%s*"(%d+%.%d+%.%d+)"')

	if version then return version end
	error('failed to read version from package.json', 0)
end

const function replace_once(
	contents: string,
	needle: string,
	replacement: string,
	label: string
): string
	const pattern =
		string.gsub(needle, '([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1')
	const updated, count = string.gsub(contents, pattern, replacement, 1)
	if count == 1 then return updated end

	error(`failed to update {label}`, 0)
end

const function apply_replacements(cwd: string, replacements: { Replacement })
	for _, change in replacements do
		const target = path_utils.resolve_path(cwd, change.path)
		const contents = fs.readFileToString(target)
		const updated = replace_once(
			contents,
			change.needle,
			change.replacement,
			change.path
		)
		fs.writeStringToFile(target, updated)
	end
end

const function version_replacements(
	current_version: string,
	next_version: string
): { Replacement }
	const current_tag = `v{current_version}`
	const next_tag = `v{next_version}`

	return {
		{
			path = 'package.json',
			needle = `"version": "{current_version}"`,
			replacement = `"version": "{next_version}"`,
		},
		{
			path = 'mise.toml',
			needle = `"github:cayasde/lutest" = "{current_version}"`,
			replacement = `"github:cayasde/lutest" = "{next_version}"`,
		},
		{
			path = 'loom.config.luau',
			needle = `version = '{current_version}'`,
			replacement = `version = '{next_version}'`,
		},
		{
			path = 'loom.config.luau',
			needle = `rev = '{current_tag}'`,
			replacement = `rev = '{next_tag}'`,
		},
		{
			path = 'loom.lock.luau',
			needle = `['lutest@{current_tag}']`,
			replacement = `['lutest@{next_tag}']`,
		},
		{
			path = 'loom.lock.luau',
			needle = `installPath = 'Packages/lutest@{current_tag}'`,
			replacement = `installPath = 'Packages/lutest@{next_tag}'`,
		},
		{
			path = 'loom.lock.luau',
			needle = `rev = '{current_tag}'`,
			replacement = `rev = '{next_tag}'`,
		},
		{
			path = 'loom.lock.luau',
			needle = `packages = {'lutest@{current_tag}'}`,
			replacement = `packages = {'lutest@{next_tag}'}`,
		},
		{
			path = 'docs/src/content/docs/installation.md',
			needle = `version = "{current_version}"`,
			replacement = `version = "{next_version}"`,
		},
		{
			path = 'docs/src/content/docs/installation.md',
			needle = `rev = "{current_tag}"`,
			replacement = `rev = "{next_tag}"`,
		},
		{
			path = 'docs/src/content/docs/pt-br/installation.md',
			needle = `version = "{current_version}"`,
			replacement = `version = "{next_version}"`,
		},
		{
			path = 'docs/src/content/docs/pt-br/installation.md',
			needle = `rev = "{current_tag}"`,
			replacement = `rev = "{next_tag}"`,
		},
	}
end

const function stage_release_files(cwd: string)
	run({
		'git',
		'add',
		'package.json',
		'mise.toml',
		'loom.config.luau',
		'loom.lock.luau',
		'docs/src/content/docs/installation.md',
		'docs/src/content/docs/pt-br/installation.md',
	}, cwd)
end

const function publish_release(version: string, remote: string, cwd: string)
	validate_version(version)
	ensure_clean_repo(cwd)
	ensure_missing_tag(version, cwd)
	ensure_missing_release(version, cwd)

	const current_version = read_current_version(cwd)
	if current_version == version then
		error(`version '{version}' is already current`, 0)
	end

	apply_replacements(cwd, version_replacements(current_version, version))

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

	stage_release_files(cwd)

	-- Bumping mise.toml to an unreleased version breaks local hooks that call
	-- `mise exec`, so publishing intentionally skips commit hooks here.
	run({
		'git',
		'commit',
		'--no-verify',
		'-m',
		`chore(release): v{version}`,
	}, cwd)

	run({ 'git', 'push', remote, 'main' }, cwd)
	run({ 'git', 'tag', '-a', `v{version}`, '-m', `v{version}` }, cwd)
	run({ 'git', 'push', remote, `v{version}` }, cwd)
	run({
		'gh',
		'release',
		'create',
		`v{version}`,
		binary_path,
		'--title',
		`v{version}`,
		'--generate-notes',
	}, cwd)

	print(`published release v{version}`)
end

const cwd = path_utils.normalize_path(process.cwd())
const version = process.args[2] or ''
const remote = process.args[3] or DEFAULT_REMOTE

if version == '' then
	error(
		'usage: lute run scripts/publish-release.luau <version> [remote]',
		0
	)
end

publish_release(version, remote, cwd)
