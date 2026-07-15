const fs = require '@std/fs'
const stringext = require '@std/stringext'
const errors = require '@core/errors'
const path_utils = require '@lutest/utils/path'
const t = require '@lutest_release'

export type RuntimeName = 'lute' | 'roblox'
export type LutestConfig = {
	roots: { string },
	ignore: { string },
	require: string,
	gitignore: boolean,
}

export type RobloxConfig = {
	universe_id: number,
	place_id: number,
	version_id: number?,
	poll_interval_seconds: number,
	timeout_seconds: number,
}

export type ProjectConfig = {
	lute: LutestConfig?,
	roblox: LutestConfig?,
	roblox_options: RobloxConfig?,
}

const CONFIG_PATH = 'lutest.toml'
const DEFAULT_LUTE_CONFIG = {
	roots = { '.' },
	ignore = {},
	require = '@lib',
	gitignore = true,
} :: LutestConfig

const function clone_strings(values: { string }): { string }
	const cloned = {} :: { string }
	for _, value in values do
		table.insert(cloned, value)
	end
	return cloned
end

const function clone_config(config: LutestConfig): LutestConfig
	return {
		roots = clone_strings(config.roots),
		ignore = clone_strings(config.ignore),
		require = config.require,
		gitignore = config.gitignore,
	}
end

const function strip_comment(line: string): string
	const comment = line:find('#', 1, true)
	return if comment == nil then line else line:sub(1, comment - 1)
end

const function parse_string(value: string): string
	const trimmed = stringext.trim(value)
	const quoted = trimmed:match '^"(.*)"$' or trimmed:match '^\'(.*)\'$'
	if quoted == nil then error(`invalid string value '{trimmed}'`) end
	return quoted
end

const function parse_boolean(value: string): boolean
	const trimmed = stringext.trim(value)
	if trimmed == 'true' then return true end
	if trimmed == 'false' then return false end
	error(`invalid boolean value '{trimmed}'`)
end

const function parse_positive_integer(value: string): number
	const parsed = tonumber(stringext.trim(value))
	if parsed == nil or parsed % 1 ~= 0 or parsed <= 0 then
		error(
			`expected a positive integer, got '{stringext.trim(
				value
			)}'`
		)
	end
	return parsed
end

const function parse_string_array(value: string): { string }
	const trimmed = stringext.trim(value)
	if trimmed:sub(1, 1) ~= '[' or trimmed:sub(-1) ~= ']' then
		error(`expected a string array, got '{trimmed}'`)
	end

	const values = {} :: { string }
	for entry in trimmed:sub(2, -2):gmatch '[^,]+' do
		if stringext.trim(entry) ~= '' then
			table.insert(values, parse_string(entry))
		end
	end
	return values
end

const function new_project_config(): ProjectConfig
	return {
		lute = nil,
		roblox = nil,
		roblox_options = nil,
	}
end

const function ensure_discovery_config(
	project: ProjectConfig,
	runtime: RuntimeName
): LutestConfig
	const current = if runtime == 'lute'
		then project.lute
		else project.roblox
	if current ~= nil then return current end

	const created = {
		roots = {},
		ignore = {},
		require = '',
		gitignore = true,
	} :: LutestConfig
	if runtime == 'lute' then
		project.lute = created
	else
		project.roblox = created
	end
	return created
end

const function ensure_roblox_options(project: ProjectConfig): RobloxConfig
	if project.roblox_options ~= nil then return project.roblox_options end

	const created = {
		universe_id = 0,
		place_id = 0,
		version_id = nil,
		poll_interval_seconds = 2,
		timeout_seconds = 300,
	} :: RobloxConfig
	project.roblox_options = created
	return created
end

const function assign_discovery(
	project: ProjectConfig,
	runtime: RuntimeName,
	key: string,
	value: string
)
	const config = ensure_discovery_config(project, runtime)
	if key == 'require' then
		config.require = parse_string(value)
		return
	end
	if key == 'roots' then
		config.roots = parse_string_array(value)
		return
	end
	error(`unsupported key 'discovery.{runtime}.{key}'`)
end

const function assign_shared_discovery(
	project: ProjectConfig,
	key: string,
	value: string
)
	if key ~= 'ignore' and key ~= 'gitignore' then
		error(`unsupported key 'discovery.{key}'`)
	end

	for _, runtime in { 'lute', 'roblox' } do
		const config =
			ensure_discovery_config(project, runtime :: RuntimeName)
		if key == 'ignore' then
			config.ignore = parse_string_array(value)
		else
			config.gitignore = parse_boolean(value)
		end
	end
end

const function assign_roblox(project: ProjectConfig, key: string, value: string)
	const config = ensure_roblox_options(project)
	if key == 'universe_id' then
		config.universe_id = parse_positive_integer(value)
		return
	end
	if key == 'place_id' then
		config.place_id = parse_positive_integer(value)
		return
	end
	if key == 'version_id' then
		config.version_id = parse_positive_integer(value)
		return
	end
	if key == 'poll_interval_seconds' then
		config.poll_interval_seconds = parse_positive_integer(value)
		return
	end
	if key == 'timeout_seconds' then
		config.timeout_seconds = parse_positive_integer(value)
		if config.timeout_seconds > 300 then
			error 'roblox.timeout_seconds must not exceed 300'
		end
		return
	end
	error(`unsupported key 'roblox.{key}'`)
end

const function parse_config(contents: string): ProjectConfig
	const project = new_project_config()
	local section = ''

	for _, raw_line in contents:split '\n' do
		const line = stringext.trim(strip_comment(raw_line))
		if line == '' then continue end

		const section_name = line:match '^%[([^%]]+)%]$'
		if section_name ~= nil then
			section = section_name
			continue
		end

		const key, value = line:match '^([%w_]+)%s*=%s*(.+)$'
		if key == nil or value == nil then
			error(`invalid config line '{line}'`)
		end
		if section == 'discovery' then
			assign_shared_discovery(project, key, value)
		elseif section == 'discovery.lute' then
			assign_discovery(project, 'lute', key, value)
		elseif section == 'discovery.roblox' then
			assign_discovery(project, 'roblox', key, value)
		elseif section == 'roblox' then
			assign_roblox(project, key, value)
		else
			error(`unsupported section '[{section}]'`)
		end
	end

	return project
end

const function resolve_config_path(config_path: string?): string
	if config_path ~= nil then
		return path_utils.resolve_from_cwd(config_path)
	end

	return path_utils.resolve_path(path_utils.cwd(), CONFIG_PATH)
end

const function configuration_error(config_path: string, details: string): never
	error(
		errors.configuration_error(
			'Could not parse configuration file.',
			{
				where = path_utils.normalize_path(config_path),
				how_to_fix = 'Use [discovery], [discovery.lute], [discovery.roblox], and [roblox] according to the Lutest configuration reference.',
				details = details,
			}
		),
		0
	)
end

const function load_project_config(config_path: string?): ProjectConfig
	const resolved_config_path = resolve_config_path(config_path)
	if not fs.exists(resolved_config_path) then
		if config_path ~= nil then
			error(
				errors.configuration_error(
					'Configuration file not found.',
					{
						where = path_utils.normalize_path(
							resolved_config_path
						),
						how_to_fix = 'Pass an existing file with `--config <path>`, or omit `--config` to use `lutest.toml` from the current directory.',
					}
				),
				0
			)
		end

		return {
			lute = clone_config(DEFAULT_LUTE_CONFIG),
			roblox = nil,
			roblox_options = nil,
		}
	end

	local result = nil :: ProjectConfig?
	local parse_error = nil :: string?
	const ok = xpcall(function()
		result = parse_config(fs.readFileToString(resolved_config_path))
	end, function(err)
		parse_error = tostring(err)
		return parse_error
	end)
	if not ok then
		configuration_error(resolved_config_path, parse_error :: string)
	end
	return result :: ProjectConfig
end

const function has_discovery_config(config: LutestConfig?): boolean
	if config == nil then return false end
	return config.require ~= '' and #config.roots > 0
end

const function default_runtime(project: ProjectConfig): RuntimeName
	if
		has_discovery_config(project.roblox)
		and not has_discovery_config(project.lute)
	then
		return 'roblox'
	end

	return 'lute'
end

const function load_config(config_path: string?): LutestConfig
	const resolved_config_path = resolve_config_path(config_path)
	const project = load_project_config(config_path)
	if
		project.lute ~= nil
		and project.lute.require ~= ''
		and #project.lute.roots > 0
	then
		return project.lute
	end

	error(
		errors.configuration_error(
			'Missing [discovery.lute] configuration.',
			{
				where = path_utils.normalize_path(
					resolved_config_path
				),
				how_to_fix = 'Add [discovery.lute] with `require` and `roots`, or run `lutest test --runtime roblox` with its matching configuration.',
			}
		),
		0
	)
end

const function load_roblox_config(
	config_path: string?
): (LutestConfig, RobloxConfig)
	const resolved_config_path = resolve_config_path(config_path)
	const project = load_project_config(config_path)
	if project.roblox == nil or project.roblox_options == nil then
		error(
			errors.configuration_error(
				'Missing Roblox runtime configuration.',
				{
					where = path_utils.normalize_path(
						resolved_config_path
					),
					how_to_fix = 'Add [discovery.roblox] with `require` and `roots`, and [roblox] with `universe_id` and `place_id`.',
				}
			),
			0
		)
	end
	if project.roblox.require == '' or #project.roblox.roots == 0 then
		error(
			errors.configuration_error(
				'Incomplete [discovery.roblox] configuration.',
				{
					where = path_utils.normalize_path(
						resolved_config_path
					),
					how_to_fix = 'Set non-empty `require` and `roots` values in [discovery.roblox].',
				}
			),
			0
		)
	end
	if
		project.roblox_options.universe_id <= 0
		or project.roblox_options.place_id <= 0
	then
		error(
			errors.configuration_error(
				'Incomplete [roblox] configuration.',
				{
					where = path_utils.normalize_path(
						resolved_config_path
					),
					how_to_fix = 'Set positive `universe_id` and `place_id` values in [roblox].',
				}
			),
			0
		)
	end
	return project.roblox, project.roblox_options
end

t.test('should read split runtime configuration', function()
	const project = parse_config [[
[discovery]
ignore = ["vendor"]
gitignore = false

[discovery.lute]
require = "@lutest_release"
roots = ["core"]

[discovery.roblox]
require = "ReplicatedStorage.Packages.lutest.lib"
roots = ["src"]

[roblox]
universe_id = 1
place_id = 2
]]
	assert(project.lute ~= nil)
	assert(project.roblox ~= nil)
	assert(project.roblox_options ~= nil)
	assert((project.lute :: LutestConfig).require == '@lutest_release')
	assert((project.roblox :: LutestConfig).ignore[1] == 'vendor')
	assert((project.roblox_options :: RobloxConfig).place_id == 2)
end)

t.test('should reject a timeout above the remote limit', function()
	const ok = pcall(function()
		parse_config [[
[roblox]
timeout_seconds = 301
]]
	end)
	assert(ok == false)
end)

t.test('should load an explicit configuration file', function()
	const temp_root = path_utils.resolve_path(
		path_utils.cwd(),
		'dist/test-tmp/config-explicit-path'
	)
	const config_path = path_utils.resolve_path(temp_root, 'roblox.toml')

	if fs.exists(temp_root) then
		fs.removeDirectory(temp_root, { recursive = true })
	end
	path_utils.ensure_directory(temp_root)
	fs.writeStringToFile(
		config_path,
		[[
[discovery.lute]
require = "@lutest_release"
roots = ["fixtures"]
]]
	)

	const project = load_project_config(config_path)
	fs.removeDirectory(temp_root, { recursive = true })

	assert(project.lute ~= nil)
	assert((project.lute :: LutestConfig).roots[1] == 'fixtures')
end)

t.test('should reject a missing explicit configuration file', function()
	const config_path = path_utils.resolve_path(
		path_utils.cwd(),
		'dist/test-tmp/missing-lutest-config.toml'
	)
	local message = ''
	const ok = xpcall(function()
		load_project_config(config_path)
	end, function(err)
		message = tostring(err)
		return message
	end)

	assert(ok == false)
	assert(message:find('Configuration file not found.', 1, true) ~= nil)
	assert(message:find(config_path, 1, true) ~= nil)
end)

t.test('should select Roblox when it is the only configured runtime', function()
	assert(default_runtime {
		lute = nil,
		roblox = {
			roots = { 'game' },
			ignore = {},
			require = 'ReplicatedStorage.Packages.lutest',
			gitignore = true,
		},
		roblox_options = nil,
	} == 'roblox')
end)

t.test(
	'should keep Lute as the default when both runtimes are configured',
	function()
		assert(default_runtime {
			lute = {
				roots = { 'src' },
				ignore = {},
				require = '@lutest_release',
				gitignore = true,
			},
			roblox = {
				roots = { 'game' },
				ignore = {},
				require = 'ReplicatedStorage.Packages.lutest',
				gitignore = true,
			},
			roblox_options = nil,
		} == 'lute')
	end
)

return {
	default_runtime = default_runtime,
	load_config = load_config,
	load_project_config = load_project_config,
	load_roblox_config = load_roblox_config,
	resolve_config_path = resolve_config_path,
}
