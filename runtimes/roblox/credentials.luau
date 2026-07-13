const fs = require '@std/fs'
const path = require '@std/path'
const process = require '@std/process'
const stringext = require '@std/stringext'
const errors = require '@core/errors'
const path_utils = require '@lutest/utils/path'
const t = require '@lutest_release'

const ENVIRONMENT_KEY = 'ROBLOX_OPEN_CLOUD_API_KEY'

const function parse_dotenv(contents: string): { [string]: string }
	const values = {} :: { [string]: string }
	for _, raw_line in contents:split '\n' do
		const line = stringext.trim(raw_line)
		if line == '' or line:sub(1, 1) == '#' then continue end
		const key, value = line:match '^([%w_]+)%s*=%s*(.*)$'
		if key == nil or value == nil then continue end
		const trimmed = stringext.trim(value)
		const quoted = trimmed:match '^"(.*)"$'
			or trimmed:match '^\'(.*)\'$'
		values[key] = quoted or trimmed
	end
	return values
end

const function load(cwd: string?): string
	const environment_value = process.env[ENVIRONMENT_KEY]
	if type(environment_value) == 'string' and environment_value ~= '' then
		return environment_value
	end

	const resolved_cwd = cwd or path_utils.cwd()
	const dotenv_path = path.join(resolved_cwd, '.env')
	if fs.exists(dotenv_path) then
		const value =
			parse_dotenv(fs.readFileToString(dotenv_path))[ENVIRONMENT_KEY]
		if value ~= nil and value ~= '' then return value end
	end

	error(
		errors.configuration_error('Roblox API key missing', {
			how_to_fix = 'Set ROBLOX_OPEN_CLOUD_API_KEY in .env or your environment.',
		}),
		0
	)
end

t.test('should parse a dotenv API key without exposing it', function()
	const values =
		parse_dotenv 'OTHER=value\nROBLOX_OPEN_CLOUD_API_KEY="secret"\n'
	assert(values.ROBLOX_OPEN_CLOUD_API_KEY == 'secret')
end)

return {
	load = load,
}
