const fs = require '@std/fs'
const process = require '@std/process'
const path = require '@std/path'
const system = require '@std/system'
const printer = require '@std/syntax/printer'
const query = require '@std/syntax/query'
const syntax = require '@std/syntax'
const syntax_utils = require '@std/syntax/utils'

const DEFAULT_ENTRY = 'cli/init.luau'
const DEFAULT_BUNDLE_OUTPUT = '.tmp/release-bundle/main.luau'
const DEFAULT_BINARY_OUTPUT = if system.win32
	then 'dist/lutest.exe'
	else 'dist/lutest'
const DEFAULT_CONFIG = 'darklua-bundle.json5'
const GENERATED_CONFIG = '.tmp-darklua-bundle.generated.json5'
const DEFAULT_DARKLUA_COMMAND = 'darklua'
const LUTEST_RELEASE_ALIAS_PLACEHOLDER = '__LUTEST_RELEASE_ALIAS__'
const RELEASE_STAGING_ROOT = '.tmp/release-staging'
const EMBEDDED_ASSETS_PATH = 'runtimes/roblox/embedded_assets.luau'
const EMBEDDED_LIBRARY_FILES = {
	'lib/init.luau',
	'lib/context.luau',
	'lib/registry.luau',
	'core/types.luau',
}
const ROBLOX_BUNDLE_SCRIPT_PATH = 'scripts/build-roblox-bundle.luau'
const RELEASE_SELF_TEST_METHODS = {
	test = true,
	skip = true,
	only = true,
	todo = true,
}
const STAGING_SKIP_SEGMENTS = {
	'.git',
	'.cache',
	'.tmp',
	'dist',
	'vendor',
}

const function normalize_path(value: path.Pathlike): string
	const formatted = path.format(path.normalize(value))
	return (formatted:gsub('\\', '/'))
end

const function current_working_directory(): string
	return normalize_path(process.cwd())
end

const function resolve_path(base: string, value: string): string
	if path.isAbsolute(value) then return normalize_path(value) end

	return normalize_path(path.join(base, value))
end

const function ensure_directory(directory: string)
	if directory == '' or directory == '.' then return end
	if fs.exists(directory) then return end

	fs.createDirectory(directory, {
		makeParents = true,
	})
end

const function tool_path(cwd: string, absolute_path: string): string
	const normalized_cwd = normalize_path(cwd)
	const normalized_path = normalize_path(absolute_path)
	const relative_path =
		normalize_path(path.relative(normalized_cwd, normalized_path))

	if relative_path == '' then return '.' end
	if string.sub(relative_path, 1, 2) == '..' then
		return normalized_path
	end

	return relative_path
end

const function resolve_darklua_command(): string
	const from_env = process.env.DARKLUA_BIN
	if type(from_env) == 'string' and from_env ~= '' then
		return from_env
	end
	return DEFAULT_DARKLUA_COMMAND
end

const function path_within_root(root: string, absolute_path: string): string?
	const relative_path = normalize_path(path.relative(root, absolute_path))
	if relative_path == '' then return '.' end
	if string.sub(relative_path, 1, 2) == '..' then return nil end

	return relative_path
end

const function stage_path(
	project_root: string,
	staging_root: string,
	absolute_path: string
): string
	const relative_path = path_within_root(project_root, absolute_path)
	if relative_path == nil then return absolute_path end
	if relative_path == '.' then return staging_root end

	return resolve_path(staging_root, relative_path)
end

const function should_skip_staging_entry(name: string): boolean
	for _, segment in STAGING_SKIP_SEGMENTS do
		if name == segment then return true end
	end

	return false
end

const function remove_path(target_path: string)
	if not fs.exists(target_path) then return end

	const target_type = fs.type(target_path)
	if target_type == 'dir' then
		fs.removeDirectory(target_path, { recursive = true })
		return
	end

	fs.remove(target_path)
end

const function copy_directory_recursive(source_dir: string, dest_dir: string)
	ensure_directory(dest_dir)

	for _, entry in fs.listDirectory(source_dir) do
		if should_skip_staging_entry(entry.name) then continue end

		const source_path =
			normalize_path(path.join(source_dir, entry.name))
		const dest_path =
			normalize_path(path.join(dest_dir, entry.name))

		if entry.type == 'dir' then
			copy_directory_recursive(source_path, dest_path)
			continue
		end

		if entry.type ~= 'file' then continue end
		ensure_directory(path.dirname(dest_path))
		fs.copy(source_path, dest_path)
	end
end

const function is_lutest_release_require(node: syntax.AstNode): boolean
	const require_call = syntax_utils.isRequireCall(node)
	if require_call == nil then return false end
	if #require_call.arguments ~= 1 then return false end

	const require_argument = syntax_utils.isExprConstantString(
		require_call.arguments[1].node
	)
	if require_argument == nil then return false end

	return require_argument.token.text == '@lutest_release'
end

const function is_stat_local(node: syntax.AstNode): syntax.AstStatLocal?
	return if node.kind == 'stat' and node.tag == 'local' then node else nil
end

const function is_stat_expr(node: syntax.AstNode): syntax.AstStatExpr?
	return if node.kind == 'stat'
			and node.tag == 'expression'
		then node
		else nil
end

const function collect_lutest_release_locals(
	ast: syntax.ParseResult
): { syntax.AstStatLocal }
	return query.findAllFromRoot(ast, is_stat_local):filter(function(stat)
		if #stat.variables ~= 1 then return false end
		if #stat.values ~= 1 then return false end

		return is_lutest_release_require(stat.values[1].node)
	end).nodes
end

const function collect_lutest_release_local_names(
	ast: syntax.ParseResult
): { [string]: boolean }
	const local_names = {} :: { [string]: boolean }

	for _, stat in collect_lutest_release_locals(ast) do
		local_names[stat.variables[1].node.name.text] = true
	end

	return local_names
end

const function matches_release_self_test_call(
	node: syntax.AstNode,
	lutest_release_locals: { [string]: boolean }
): boolean
	const stat = is_stat_expr(node)
	if stat == nil then return false end

	const call = syntax_utils.isExprCall(stat.expression)
	if call == nil then return false end

	const method_access = syntax_utils.isExprIndexName(call.func)
	if method_access == nil then return false end

	const receiver = syntax_utils.isExprLocal(method_access.expression)
	if receiver == nil then return false end
	if not lutest_release_locals[receiver['local'].name.text] then
		return false
	end

	return RELEASE_SELF_TEST_METHODS[method_access.index.text] == true
end

const function collect_self_test_replacements(
	ast: syntax.ParseResult,
	lutest_release_locals: { [string]: boolean }
): any
	const matches = query.findAllFromRoot(ast, is_stat_expr)
		:filter(function(node)
			return matches_release_self_test_call(
				node,
				lutest_release_locals
			)
		end)

	return matches:replace(function()
		return ''
	end)
end

const function count_remaining_local_uses(
	ast: syntax.ParseResult,
	local_name: string
): number
	return #query.findAllFromRoot(ast, syntax_utils.isExprLocal)
		:filter(function(local_ref)
			return local_ref['local'].name.text == local_name
		end).nodes
end

const function strip_release_self_tests(source: string): string
	local current_source = source

	while true do
		const ast = syntax.parse(current_source)
		const lutest_release_locals =
			collect_lutest_release_local_names(ast)
		if next(lutest_release_locals) == nil then
			return current_source
		end

		const self_test_replacements = collect_self_test_replacements(
			ast,
			lutest_release_locals
		)

		if next(self_test_replacements) == nil then
			local require_replacements = {} :: any

			for _, stat in collect_lutest_release_locals(ast) do
				const local_name =
					stat.variables[1].node.name.text
				const remaining_local_uses =
					count_remaining_local_uses(
						ast,
						local_name
					)

				if remaining_local_uses == 0 then
					require_replacements[stat] = ''
				end
			end

			if next(require_replacements) == nil then
				return current_source
			end

			current_source =
				printer.printFile(ast, require_replacements)
			continue
		end

		current_source = printer.printFile(ast, self_test_replacements)
	end
end

const function strip_release_self_tests_from_file(filepath: string)
	const original_source = fs.readFileToString(filepath)
	const stripped_source = strip_release_self_tests(original_source)
	if stripped_source == original_source then return end

	fs.writeStringToFile(filepath, stripped_source)
end

const function strip_release_self_tests_in_tree(root_dir: string)
	for _, entry in fs.listDirectory(root_dir) do
		if should_skip_staging_entry(entry.name) then continue end

		const entry_path =
			normalize_path(path.join(root_dir, entry.name))
		if entry.type == 'dir' then
			strip_release_self_tests_in_tree(entry_path)
			continue
		end

		if entry.type ~= 'file' then continue end
		if entry.name:sub(-7) == '.d.luau' then continue end
		if path.extname(entry_path) ~= '.luau' then continue end

		strip_release_self_tests_from_file(entry_path)
	end
end

const function write_embedded_roblox_assets(staging_root: string)
	const lines = {
		'return {',
		'\tlibrary = {',
	} :: { string }

	for _, relative_path in EMBEDDED_LIBRARY_FILES do
		const source_path = resolve_path(staging_root, relative_path)
		if not fs.exists(source_path) then
			error(
				`missing embedded Roblox library source '{relative_path}'`,
				0
			)
		end
		table.insert(
			lines,
			`\t\t[{string.format('%q', relative_path)}] = {string.format(
				'%q',
				fs.readFileToString(source_path)
			)},`
		)
	end

	const bundle_script_path =
		resolve_path(staging_root, ROBLOX_BUNDLE_SCRIPT_PATH)
	if not fs.exists(bundle_script_path) then
		error('missing embedded Roblox bundle script', 0)
	end

	table.insert(lines, '\t},')
	table.insert(
		lines,
		`\tbundle_script = {string.format(
			'%q',
			fs.readFileToString(bundle_script_path)
		)},`
	)
	table.insert(lines, '}')

	const output_path = resolve_path(staging_root, EMBEDDED_ASSETS_PATH)
	fs.writeStringToFile(output_path, table.concat(lines, '\n'))
end

const function create_release_staging(project_root: string): string
	const staging_root = resolve_path(project_root, RELEASE_STAGING_ROOT)
	remove_path(staging_root)
	copy_directory_recursive(project_root, staging_root)
	strip_release_self_tests_in_tree(staging_root)
	write_embedded_roblox_assets(staging_root)

	return staging_root
end

const function to_darklua_alias(alias_value: string): string
	if
		string.sub(alias_value, 1, 1) == '.'
		or string.sub(alias_value, 1, 1) == '/'
	then
		return alias_value
	end

	return `./{alias_value}`
end

const function create_darklua_config(cwd: string, config_path: string): string
	if not fs.exists(config_path) then
		error(`missing darklua config '{config_path}'`, 0)
	end

	const config_source = fs.readFileToString(config_path)
	const generated_source = string.gsub(
		config_source,
		LUTEST_RELEASE_ALIAS_PLACEHOLDER,
		to_darklua_alias 'lib'
	)
	const generated_config_path = resolve_path(cwd, GENERATED_CONFIG)

	ensure_directory(
		normalize_path(path.format(path.dirname(generated_config_path)))
	)
	fs.writeStringToFile(generated_config_path, generated_source)

	return generated_config_path
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
): number
	if not fs.exists(entry_path) then
		error(`missing entry module '{entry_path}'`, 0)
	end

	ensure_directory(normalize_path(path.format(path.dirname(bundle_path))))

	const darklua_command = resolve_darklua_command()
	ensure_darklua_available(cwd, darklua_command)
	const generated_config_path = create_darklua_config(cwd, config_path)
	const result = process.run({
		darklua_command,
		'process',
		tool_path(cwd, entry_path),
		tool_path(cwd, bundle_path),
		'--config',
		tool_path(cwd, generated_config_path),
	}, {
		cwd = cwd,
		stdio = 'inherit',
	})

	if result.exitcode ~= 0 then return result.exitcode end
	print(`bundled entry: {bundle_path}`)
	return 0
end

const function compile_bundle(
	cwd: string,
	bundle_path: string,
	binary_path: string
): number
	if not fs.exists(bundle_path) then
		error(`missing bundled entry '{bundle_path}'`, 0)
	end

	ensure_directory(normalize_path(path.format(path.dirname(binary_path))))

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

	if result.exitcode ~= 0 then return result.exitcode end
	print(`built binary: {binary_path}`)
	return 0
end

const cwd = current_working_directory()
const entry_path = resolve_path(cwd, process.args[2] or DEFAULT_ENTRY)
const bundle_path = resolve_path(cwd, process.args[3] or DEFAULT_BUNDLE_OUTPUT)
const binary_path = resolve_path(cwd, process.args[4] or DEFAULT_BINARY_OUTPUT)
const config_path = resolve_path(cwd, DEFAULT_CONFIG)
const staging_root = create_release_staging(cwd)
const staged_entry_path = stage_path(cwd, staging_root, entry_path)
const staged_config_path = stage_path(cwd, staging_root, config_path)

local exit_code = 0
local build_error = nil :: unknown
const ok = xpcall(function()
	exit_code = bundle_entry(
		staging_root,
		staged_entry_path,
		bundle_path,
		staged_config_path
	)
	if exit_code ~= 0 then return end

	exit_code = compile_bundle(cwd, bundle_path, binary_path)
end, function(err)
	build_error = err
	return err
end)

remove_path(staging_root)

if not ok then error(build_error, 0) end
if exit_code ~= 0 then process.exit(exit_code) end
