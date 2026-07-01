const fs = require '@std/fs'
const path = require '@std/path'
const process = require '@std/process'
const stringext = require '@std/stringext'

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

const function normalize_path(value: path.Pathlike): string
	const formatted = path.format(path.normalize(value))
	return (formatted:gsub('\\', '/'))
end

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

	warn(`warning: ignoring unsupported lutest.toml key '{key}'`)
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

	warn(`warning: ignoring unsupported lutest.toml key '{key}'`)
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

		pending_key, pending_array, _ = continue_pending_array(
			config,
			current_section,
			pending_key,
			pending_array,
			line
		)
		if pending_key == nil and pending_array == '' then
			const section_name = parse_section_name(line)
			if section_name ~= nil then
				current_section = section_name
				continue
			end

			const key, value = parse_assignment(line)
			if key == nil or value == nil then
				warn(
					`warning: ignoring unsupported lutest.toml line '{line}'`
				)
				continue
			end

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
	const resolved_cwd = if cwd == nil
		then normalize_path(process.cwd())
		else cwd
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
			`failed to parse '{normalize_path(config_path)}': {parse_error}`,
			0
		)
	end

	return config :: LutestConfig
end

return {
	load_config = load_config,
}
