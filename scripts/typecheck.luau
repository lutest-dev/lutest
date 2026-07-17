const fs = require '@std/fs'
const json = require '@std/json'
const process = require '@std/process'

type JsonObject = json.Object
type StringSet = { [string]: boolean }

const PROJECT_PREFIXES = {
	'core/',
	'cli/',
	'game/',
	'fixtures/',
	'lib/',
	'runtimes/',
	'scripts/',
	'utils/',
}

const IGNORE_GLOBS = {
	'.github/**',
	'.husky/**',
	'.tmp/**',
	'scripts/build-roblox-bundle.luau',
	'.vscode/**',
	'dist/**',
	'docs/**',
	'node_modules/**',
	'Packages/**',
	'luau_packages/**',
	'vendor/**',
	'**/.lute/**',
}

const PROJECT_ROOTS = {
	'core',
	'cli',
	'game',
	'fixtures',
	'lib',
	'runtimes',
	'scripts',
	'utils',
}

const VSCODE_SETTINGS_PATH = '.vscode/settings.json'
const GENERATED_SETTINGS_PATH = '.tmp/luau-lsp-typecheck.settings.json'
const ROBLOX_DEFS_CACHE_PATH = '.cache/luau-lsp/globalTypes.roblox.d.luau'
const FFLAG_RENAMES = {
	LuauConst = 'LuauConst2',
}

const function read_editor_settings(): JsonObject?
	if not fs.exists(VSCODE_SETTINGS_PATH) then return nil end

	const settings_source = fs.readFileToString(VSCODE_SETTINGS_PATH)
	const settings_value = json.deserialize(settings_source)

	return json.asObject(settings_value)
end

const function get_setting_string(settings: JsonObject?, key: string): string?
	if settings == nil then return nil end

	const value = settings[key]
	if typeof(value) == 'string' then return value end

	return nil
end

const function get_setting_boolean(settings: JsonObject?, key: string): boolean?
	if settings == nil then return nil end

	const value = settings[key]
	if typeof(value) == 'boolean' then return value end

	return nil
end

const function get_definition_files(settings: JsonObject?): JsonObject?
	if settings == nil then return nil end

	const value = settings['luau-lsp.types.definitionFiles']
	return json.asObject(value)
end

const function is_http_url(value: string): boolean
	return value:sub(1, 7) == 'http://' or value:sub(1, 8) == 'https://'
end

const function resolve_roblox_definitions_path(settings: JsonObject?): string?
	if
		get_setting_string(settings, 'luau-lsp.platform.type')
		~= 'roblox'
	then
		return nil
	end

	const definition_files = get_definition_files(settings)
	if definition_files == nil then
		error 'Roblox platform requires `luau-lsp.types.definitionFiles["@roblox"]` to be configured.'
	end

	const roblox_definitions = definition_files['@roblox']
	if typeof(roblox_definitions) ~= 'string' then
		error 'Roblox platform requires `luau-lsp.types.definitionFiles["@roblox"]` to be a string path or URL.'
	end

	if is_http_url(roblox_definitions) then
		if fs.exists(ROBLOX_DEFS_CACHE_PATH) then
			return ROBLOX_DEFS_CACHE_PATH
		end

		error 'Roblox definitions cache is missing. Run `mise run ensure-roblox-defs` before typechecking.'
	end

	if not fs.exists(roblox_definitions) then
		error(
			`Configured Roblox definitions file '{roblox_definitions}' does not exist.`
		)
	end

	return roblox_definitions
end

const function resolve_sourcemap_path(settings: JsonObject?): string?
	if
		get_setting_string(settings, 'luau-lsp.platform.type')
		~= 'roblox'
	then
		return nil
	end

	if
		get_setting_boolean(settings, 'luau-lsp.sourcemap.enabled')
		== false
	then
		return nil
	end

	const configured_path = get_setting_string(
		settings,
		'luau-lsp.sourcemap.sourcemapFile'
	) or 'sourcemap.json'

	if fs.exists(configured_path) then return configured_path end

	return nil
end

const function append_analyze_targets(args: { string })
	for _, glob in IGNORE_GLOBS do
		table.insert(args, '--ignore')
		table.insert(args, glob)
	end

	for _, root in PROJECT_ROOTS do
		table.insert(args, root)
	end
end

const function sanitize_definition_files(
	settings: JsonObject?,
	sanitized: JsonObject,
	roblox_definitions_path: string?
)
	const definition_files = get_definition_files(settings)
	if definition_files == nil then return end

	local sanitized_definition_files = json.object {}
	local has_definition_files = false

	for package_name, definitions_path in definition_files do
		if typeof(definitions_path) ~= 'string' then continue end

		if
			package_name == '@roblox'
			and roblox_definitions_path ~= nil
		then
			sanitized_definition_files[package_name] =
				roblox_definitions_path
		else
			sanitized_definition_files[package_name] =
				definitions_path
		end

		has_definition_files = true
	end

	if has_definition_files then
		sanitized['luau-lsp.types.definitionFiles'] =
			sanitized_definition_files
	end
end

const function sanitize_editor_settings(
	settings: JsonObject,
	roblox_definitions_path: string?
): JsonObject
	const sanitized = json.object {}

	for key, value in settings do
		if key == 'luau-lsp.fflags.override' then continue end
		if key == 'luau-lsp.types.definitionFiles' then continue end

		sanitized[key] = value
	end

	const overrides = settings['luau-lsp.fflags.override']
	const override_object = json.asObject(overrides)
	if override_object ~= nil then
		local sanitized_overrides = json.object {}
		local has_overrides = false

		for flag_name, flag_value in override_object do
			local normalized_flag_name = FFLAG_RENAMES[flag_name]
				or flag_name
			sanitized_overrides[normalized_flag_name] = flag_value
			has_overrides = true
		end

		if has_overrides then
			sanitized['luau-lsp.fflags.override'] =
				sanitized_overrides
		end
	end

	sanitize_definition_files(settings, sanitized, roblox_definitions_path)

	return sanitized
end

const function write_analyze_settings(
	settings: JsonObject?,
	roblox_definitions_path: string?
): string?
	if settings == nil then return nil end

	fs.createDirectory('.tmp', { makeParents = true })
	fs.writeStringToFile(
		GENERATED_SETTINGS_PATH,
		json.serialize(
			sanitize_editor_settings(
				settings,
				roblox_definitions_path
			),
			true
		)
	)

	return GENERATED_SETTINGS_PATH
end

const function build_analyze_args(
	settings_path: string?,
	sourcemap_path: string?
): { string }
	const args = {
		'luau-lsp',
		'analyze',
	} :: { string }

	if settings_path == nil then
		table.insert(args, '--platform=standard')
		table.insert(args, '--flag')
		table.insert(args, 'LuauSolverV2=true')
	else
		table.insert(args, '--settings')
		table.insert(args, settings_path)
	end

	if sourcemap_path ~= nil then
		table.insert(args, '--sourcemap')
		table.insert(args, sourcemap_path)
	end

	append_analyze_targets(args)

	return args
end

const function normalize_line(line: string): string
	return (line:gsub('\\', '/'))
end

const function is_project_diagnostic_start(line: string): boolean
	const normalized = normalize_line(line)

	for _, prefix in PROJECT_PREFIXES do
		if normalized:sub(1, #prefix) == prefix then return true end
	end

	return false
end

const function split_lines(output: string): { string }
	const lines = {} :: { string }

	for _, line in output:split '\n' do
		if line:sub(-1) == '\r' then
			table.insert(lines, line:sub(1, -2))
			continue
		end

		table.insert(lines, line)
	end

	return lines
end

const function flush_current_block(
	filtered: { string },
	seen_blocks: StringSet,
	current_block: { string }
)
	if #current_block == 0 then return end

	const key = table.concat(current_block, '\n')
	if seen_blocks[key] then return end

	seen_blocks[key] = true

	for _, line in current_block do
		table.insert(filtered, line)
	end

	table.insert(filtered, '')
end

const function collect_project_diagnostics(output: string): { string }
	const filtered = {} :: { string }
	const seen_blocks = {} :: StringSet
	local current_block = {} :: { string }
	local keep_block = false

	for _, line in split_lines(output) do
		if line == '' then
			flush_current_block(
				filtered,
				seen_blocks,
				current_block
			)
			current_block = {}
			keep_block = false
			continue
		end

		if is_project_diagnostic_start(line) then
			flush_current_block(
				filtered,
				seen_blocks,
				current_block
			)
			current_block = { line }
			keep_block = true
			continue
		end

		if keep_block then table.insert(current_block, line) end
	end

	flush_current_block(filtered, seen_blocks, current_block)

	while #filtered > 0 and filtered[#filtered] == '' do
		table.remove(filtered)
	end

	return filtered
end

const function cleanup_temporary_settings(settings_path: string?)
	if settings_path ~= nil and fs.exists(settings_path) then
		fs.remove(settings_path)
	end
end

const function main()
	const settings = read_editor_settings()
	const roblox_definitions_path =
		resolve_roblox_definitions_path(settings)
	const sourcemap_path = resolve_sourcemap_path(settings)
	const settings_path =
		write_analyze_settings(settings, roblox_definitions_path)
	const result =
		process.run(build_analyze_args(settings_path, sourcemap_path))
	const combined_output = result.stdout .. result.stderr
	const diagnostics = collect_project_diagnostics(combined_output)

	cleanup_temporary_settings(settings_path)

	if #diagnostics > 0 then
		print(table.concat(diagnostics, '\n'))
		process.exit(1)
	end

	if not result.ok then
		local trimmed_output = combined_output:gsub('%s+$', '')

		if trimmed_output ~= '' then
			print(trimmed_output)
		else
			print(
				`luau-lsp analyze exited with code {result.exitcode}.`
			)
		end

		process.exit(1)
	end

	print 'Typecheck passed for project-owned files.'
end

local err = nil :: string?
const ok = xpcall(main, function(error_value)
	err = tostring(error_value)
	return err
end)

if not ok then
	print(tostring(err))
	process.exit(1)
end
