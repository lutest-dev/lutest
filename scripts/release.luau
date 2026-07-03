const fs = require '@std/fs'
const process = require '@std/process'
const path = require '@std/path'
const path_utils = require '@lutest/utils/path'
const system = require '@std/system'

const DEFAULT_ENTRY = 'cli/init.luau'
const DEFAULT_BUNDLE_OUTPUT = '.tmp/release-bundle/main.luau'
const DEFAULT_BINARY_OUTPUT = if system.win32
	then 'dist/lutest.exe'
	else 'dist/lutest'
const DEFAULT_CONFIG = 'darklua-bundle.json5'
const DEFAULT_DARKLUA_COMMAND = 'darklua'

const function tool_path(cwd: string, absolute_path: string): string
	const normalized_cwd = path_utils.normalize_path(cwd)
	const normalized_path = path_utils.normalize_path(absolute_path)
	const relative_path = path_utils.normalize_path(
		path.relative(normalized_cwd, normalized_path)
	)

	if relative_path == '' then return '.' end
	if string.sub(relative_path, 1, 2) == '..' then return normalized_path end

	return relative_path
end

const function resolve_darklua_command(): string
	const from_env = process.env.DARKLUA_BIN
	if type(from_env) == 'string' and from_env ~= '' then
		return from_env
	end
	return DEFAULT_DARKLUA_COMMAND
end

const function ensure_darklua_available(cwd: string, command: string)
	const result = process.run({ command, '--version' }, {
		cwd = cwd,
	})
	if result.exitcode == 0 then return end

	error(
		`missing darklua executable '{command}'. Install darklua and expose it on PATH, or set DARKLUA_BIN to its full path.`,
		0
	)
end

const function bundle_entry(
	cwd: string,
	entry_path: string,
	bundle_path: string,
	config_path: string
)
	if not fs.exists(entry_path) then
		error(`missing entry module '{entry_path}'`, 0)
	end

	if not fs.exists(config_path) then
		error(`missing darklua config '{config_path}'`, 0)
	end

	path_utils.ensure_directory(
		path_utils.normalize_path(path.dirname(bundle_path))
	)

	const darklua_command = resolve_darklua_command()
	ensure_darklua_available(cwd, darklua_command)
	const result = process.run({
		darklua_command,
		'process',
		tool_path(cwd, entry_path),
		tool_path(cwd, bundle_path),
		'--config',
		tool_path(cwd, config_path),
	}, {
		cwd = cwd,
		stdio = 'inherit',
	})

	if result.exitcode ~= 0 then process.exit(result.exitcode) end
	print(`bundled entry: {bundle_path}`)
end

const function compile_bundle(
	cwd: string,
	bundle_path: string,
	binary_path: string
)
	if not fs.exists(bundle_path) then
		error(`missing bundled entry '{bundle_path}'`, 0)
	end

	path_utils.ensure_directory(
		path_utils.normalize_path(path.dirname(binary_path))
	)

	if fs.exists(binary_path) then fs.remove(binary_path) end

	const result = process.run({
		'lute',
		'compile',
		tool_path(cwd, bundle_path),
		'--output',
		tool_path(cwd, binary_path),
	}, {
		cwd = cwd,
		stdio = 'inherit',
	})

	if result.exitcode ~= 0 then process.exit(result.exitcode) end
	print(`built binary: {binary_path}`)
end

const cwd = path_utils.normalize_path(process.cwd())
const entry_path =
	path_utils.resolve_path(cwd, process.args[2] or DEFAULT_ENTRY)
const bundle_path =
	path_utils.resolve_path(cwd, process.args[3] or DEFAULT_BUNDLE_OUTPUT)
const binary_path =
	path_utils.resolve_path(cwd, process.args[4] or DEFAULT_BINARY_OUTPUT)
const config_path = path_utils.resolve_path(cwd, DEFAULT_CONFIG)

bundle_entry(cwd, entry_path, bundle_path, config_path)
compile_bundle(cwd, bundle_path, binary_path)
