const fs = require '@std/fs'
const errors = require '@core/errors'
const path_utils = require '@lutest/utils/path'
const path = require '@std/path'
const stringext = require '@std/stringext'
const t = require '@lutest_release'

export type LutestConfig = {
	roots: { string },
	ignore: { string },
	require: string,
	gitignore: boolean,
}

const CONFIG_PATH = 'lutest.toml'
const DISCOVERY_SECTION = 'discovery'

const DEFAULT_CONFIG = {
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

const function default_config(): LutestConfig
	return {
		roots = clone_strings(DEFAULT_CONFIG.roots),
		ignore = clone_strings(DEFAULT_CONFIG.ignore),
		require = DEFAULT_CONFIG.require,
		gitignore = DEFAULT_CONFIG.gitignore,
	}
end

const function strip_comment(line: string): string
	const comment_start = line:find('#', 1, true)
	if comment_start == nil then return line end

	return line:sub(1, comment_start - 1)
end

const function parse_quoted_string(value: string): string
	const trimmed = stringext.trim(value)

	const double_quoted = trimmed:match '^"(.*)"$'
	if double_quoted ~= nil then return double_quoted end

	const single_quoted = trimmed:match '^\'(.*)\'$'
	if single_quoted ~= nil then return single_quoted end

	error(`invalid string value '{trimmed}'`)
end

const function parse_boolean(value: string): boolean
	const trimmed = stringext.trim(value)
	if trimmed == 'true' then return true end
	if trimmed == 'false' then return false end

	error(`invalid boolean value '{trimmed}'`)
end

const function parse_string_array(body: string): { string }
	const values = {} :: { string }

	for entry in body:gmatch '[^,]+' do
		if stringext.trim(entry) == '' then continue end
		table.insert(values, parse_quoted_string(entry))
	end

	return values
end

const function assign_discovery_scalar(
	config: LutestConfig,
	key: string,
	value: string
)
	if key == 'require' then
		config.require = parse_quoted_string(value)
		return
	end

	if key == 'gitignore' then
		config.gitignore = parse_boolean(value)
		return
	end

	if key == 'roots' or key == 'ignore' then
		error(`lutest.toml key '{key}' must be an array`)
	end
end

const function assign_discovery_array(
	config: LutestConfig,
	key: string,
	value: string
)
	if key == 'roots' then
		config.roots = parse_string_array(value)
		return
	end

	if key == 'ignore' then
		config.ignore = parse_string_array(value)
		return
	end

	if key == 'require' then
		error(`lutest.toml key '{key}' must be a string`)
	end

	if key == 'gitignore' then
		error(`lutest.toml key '{key}' must be a boolean`)
	end
end

const function parse_section_name(line: string): string?
	return line:match '^%[([%w_-]+)%]$'
end

const function parse_assignment(line: string): (string?, string?)
	return line:match '^(%w+)%s*=%s*(.+)$'
end

const function parse_inline_array(value: string): string?
	const body = value:sub(2)
	const closing_index = body:find(']', 1, true)
	if closing_index == nil then return nil end

	return stringext.trim(body:sub(1, closing_index - 1))
end

const function continue_pending_array(
	config: LutestConfig,
	current_section: string?,
	pending_key: string?,
	pending_array: string,
	line: string
): (string?, string, boolean)
	if pending_key == nil then return nil, pending_array, false end

	pending_array ..= ` {line}`
	const closing_index = pending_array:find(']', 1, true)
	if closing_index == nil then return pending_key, pending_array, true end

	if current_section == DISCOVERY_SECTION then
		assign_discovery_array(
			config,
			pending_key,
			stringext.trim(pending_array:sub(1, closing_index - 1))
		)
	end

	return nil, '', true
end

const function handle_discovery_assignment(
	config: LutestConfig,
	key: string,
	value: string
): (string?, string)
	const trimmed_value = stringext.trim(value)
	if not stringext.hasPrefix(trimmed_value, '[') then
		assign_discovery_scalar(config, key, trimmed_value)
		return nil, ''
	end

	const inline_array = parse_inline_array(trimmed_value)
	if inline_array ~= nil then
		assign_discovery_array(config, key, inline_array)
		return nil, ''
	end

	return key, trimmed_value:sub(2)
end

const function parse_config(contents: string): LutestConfig
	const config = default_config()
	local current_section = nil :: string?
	local pending_key = nil :: string?
	local pending_array = ''

	for _, raw_line in contents:split '\n' do
		const line = stringext.trim(strip_comment(raw_line))
		if line == '' then continue end

		local continued = false
		pending_key, pending_array, continued = continue_pending_array(
			config,
			current_section,
			pending_key,
			pending_array,
			line
		)
		if continued then continue end

		if pending_key == nil and pending_array == '' then
			const section_name = parse_section_name(line)
			if section_name ~= nil then
				current_section = section_name
				continue
			end

			const key, value = parse_assignment(line)
			if key == nil or value == nil then continue end

			if current_section ~= DISCOVERY_SECTION then
				continue
			end
			pending_key, pending_array =
				handle_discovery_assignment(config, key, value)
			continue
		end

		if pending_key ~= nil then continue end
		if pending_array == '' then continue end
	end

	if pending_key ~= nil then
		error(`unterminated array for lutest.toml key '{pending_key}'`)
	end

	return config
end

const function load_config(cwd: string?): LutestConfig
	const resolved_cwd = if cwd == nil then path_utils.cwd() else cwd
	const config_path = path.join(resolved_cwd, CONFIG_PATH)
	if not fs.exists(config_path) then return default_config() end

	local config = nil :: LutestConfig?
	local parse_error = nil :: string?
	const contents = fs.readFileToString(config_path)

	const ok = xpcall(function()
		config = parse_config(contents)
	end, function(err)
		parse_error = tostring(err)
		return parse_error
	end)

	if not ok then
		error(
			errors.configuration_error(
				`Could not parse config file '{path_utils.normalize_path(
					config_path
				)}'.`,
				{
					where = path_utils.normalize_path(
						config_path
					),
					how_to_fix = 'Fix the invalid discovery config in `lutest.toml` and run the command again.',
					details = parse_error,
				}
			),
			0
		)
	end

	return config :: LutestConfig
end

t.test('should use default config without lutest.toml', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd = path_utils.resolve_path(temp_root, 'config-missing')

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })

	const config = load_config(temp_cwd)

	assert(#config.roots == 1)
	assert(config.roots[1] == '.')
	assert(#config.ignore == 0)
	assert(config.require == '@lib')
	assert(config.gitignore == true)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should read valid discovery config', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd = path_utils.resolve_path(temp_root, 'config-valid')
	const config_path = path.join(temp_cwd, CONFIG_PATH)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		config_path,
		[[
[discovery]
require = "@lutest_release"
roots = ["src", "tests"]
ignore = ["vendor", ".git"]
gitignore = false
]]
	)

	const config = load_config(temp_cwd)

	assert(config.require == '@lutest_release')
	assert(config.gitignore == false)
	assert(#config.roots == 2)
	assert(config.roots[1] == 'src')
	assert(config.roots[2] == 'tests')
	assert(#config.ignore == 2)
	assert(config.ignore[1] == 'vendor')
	assert(config.ignore[2] == '.git')

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should accept inline and multiline arrays', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd = path_utils.resolve_path(temp_root, 'config-arrays')
	const config_path = path.join(temp_cwd, CONFIG_PATH)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		config_path,
		[[
[discovery]
roots = ["src", "tests"]
ignore = [
	"vendor",
	".git",
]
]]
	)

	const config = load_config(temp_cwd)

	assert(#config.roots == 2)
	assert(config.roots[1] == 'src')
	assert(config.roots[2] == 'tests')
	assert(#config.ignore == 2)
	assert(config.ignore[1] == 'vendor')
	assert(config.ignore[2] == '.git')

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should ignore assignments outside [discovery]', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd = path_utils.resolve_path(temp_root, 'config-sections')
	const config_path = path.join(temp_cwd, CONFIG_PATH)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		config_path,
		[[
[tool]
require = "@ignored"
roots = ["ignored"]
ignore = ["ignored"]
gitignore = false

[discovery]
require = "@lutest_release"
roots = ["src"]

[other]
require = "@ignored-again"
roots = ["ignored-again"]
ignore = ["ignored-again"]
gitignore = false
]]
	)

	const config = load_config(temp_cwd)

	assert(config.require == '@lutest_release')
	assert(#config.roots == 1)
	assert(config.roots[1] == 'src')
	assert(#config.ignore == 0)
	assert(config.gitignore == true)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should ignore unsupported discovery keys', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'config-unsupported')
	const config_path = path.join(temp_cwd, CONFIG_PATH)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		config_path,
		[[
[discovery]
require = "@lutest_release"
roots = ["src"]
ignore = ["vendor"]
gitignore = false
reporter = "spec"
watch = true
]]
	)

	const config = load_config(temp_cwd)

	assert(config.require == '@lutest_release')
	assert(#config.roots == 1)
	assert(config.roots[1] == 'src')
	assert(#config.ignore == 1)
	assert(config.ignore[1] == 'vendor')
	assert(config.gitignore == false)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should reject non-string require', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'config-require-invalid')
	const config_path = path.join(temp_cwd, CONFIG_PATH)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		config_path,
		[[
[discovery]
require = true
]]
	)

	local message = nil :: string?
	const ok = xpcall(function()
		load_config(temp_cwd)
	end, function(err)
		message = tostring(err)
		return message
	end)

	assert(ok == false)
	assert(message ~= nil)
	assert(message:find('[lutest] ConfigurationError:', 1, true) ~= nil)
	assert(message:find('Could not parse config file \'', 1, true) ~= nil)
	assert(message:find('invalid string value \'true\'', 1, true) ~= nil)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should reject non-array roots and ignore', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'config-arrays-invalid')
	const config_path = path.join(temp_cwd, CONFIG_PATH)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })

	fs.writeStringToFile(
		config_path,
		[[
[discovery]
roots = "src"
]]
	)

	local roots_message = nil :: string?
	const roots_ok = xpcall(function()
		load_config(temp_cwd)
	end, function(err)
		roots_message = tostring(err)
		return roots_message
	end)

	assert(roots_ok == false)
	assert(roots_message ~= nil)
	assert(
		roots_message:find('[lutest] ConfigurationError:', 1, true)
			~= nil
	)
	assert(
		roots_message:find(
			'lutest.toml key \'roots\' must be an array',
			1,
			true
		) ~= nil
	)

	fs.writeStringToFile(
		config_path,
		[[
[discovery]
ignore = false
]]
	)

	local ignore_message = nil :: string?
	const ignore_ok = xpcall(function()
		load_config(temp_cwd)
	end, function(err)
		ignore_message = tostring(err)
		return ignore_message
	end)

	assert(ignore_ok == false)
	assert(ignore_message ~= nil)
	assert(
		ignore_message:find('[lutest] ConfigurationError:', 1, true)
			~= nil
	)
	assert(
		ignore_message:find(
			'lutest.toml key \'ignore\' must be an array',
			1,
			true
		) ~= nil
	)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should reject non-boolean gitignore', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'config-gitignore-invalid')
	const config_path = path.join(temp_cwd, CONFIG_PATH)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		config_path,
		[[
[discovery]
gitignore = "yes"
]]
	)

	local message = nil :: string?
	const ok = xpcall(function()
		load_config(temp_cwd)
	end, function(err)
		message = tostring(err)
		return message
	end)

	assert(ok == false)
	assert(message ~= nil)
	assert(message:find('[lutest] ConfigurationError:', 1, true) ~= nil)
	assert(message:find('invalid boolean value \'"yes"\'', 1, true) ~= nil)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should fail on unterminated discovery array', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'config-array-unterminated')
	const config_path = path.join(temp_cwd, CONFIG_PATH)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		config_path,
		[[
[discovery]
roots = [
	"src",
	"tests"
]]
	)

	local message = nil :: string?
	const ok = xpcall(function()
		load_config(temp_cwd)
	end, function(err)
		message = tostring(err)
		return message
	end)

	assert(ok == false)
	assert(message ~= nil)
	assert(message:find('[lutest] ConfigurationError:', 1, true) ~= nil)
	assert(message:find('lutest.toml key \'roots\'', 1, true) ~= nil)
	assert(message:find('unterminated array', 1, true) ~= nil)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should keep defaults for omitted discovery keys', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'config-omitted-defaults')
	const config_path = path.join(temp_cwd, CONFIG_PATH)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		config_path,
		[[
[discovery]
roots = ["src"]
]]
	)

	const config = load_config(temp_cwd)

	assert(#config.roots == 1)
	assert(config.roots[1] == 'src')
	assert(#config.ignore == 0)
	assert(config.require == '@lib')
	assert(config.gitignore == true)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

return {
	load_config = load_config,
}
