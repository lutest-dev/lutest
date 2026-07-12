const fs = require '@std/fs'
const io = require '@std/io'
const path = require '@std/path'
const process = require '@std/process'
const stringext = require '@std/stringext'
const errors = require '@core/errors'
const tint = require '@packages/tint'
const tty = require '@lutest/utils/tty'
const t = require '@lutest_release'

export type RuntimeSelection = 'lute' | 'roblox' | 'both'

export type SetupConfig = {
	runtime: RuntimeSelection,
	lute_require: string?,
	lute_root: string?,
	roblox_require: string?,
	roblox_root: string?,
	universe_id: number?,
	place_id: number?,
}

type Prompt = (message: string) -> string
type Confirm = (message: string, value: string) -> ()
type Warn = (message: string) -> ()

const CONFIG_PATH = 'lutest.toml'
const DEFAULT_LUTE_REQUIRE = '@lutest_release'
const DEFAULT_LUTE_ROOT = 'src'
const DEFAULT_ROBLOX_REQUIRE = 'ReplicatedStorage.Packages.lutest'
const DEFAULT_ROBLOX_ROOT = 'game'

const function includes_lute(runtime: RuntimeSelection): boolean
	return runtime == 'lute' or runtime == 'both'
end

const function includes_roblox(runtime: RuntimeSelection): boolean
	return runtime == 'roblox' or runtime == 'both'
end

const function normalize_input(value: string): string
	return stringext.trim(value):lower()
end

const function parse_runtime(value: string): RuntimeSelection?
	const normalized = normalize_input(value)
	if normalized == 'lute' then return 'lute' end
	if normalized == 'roblox' then return 'roblox' end
	if normalized == 'both' then return 'both' end
	return nil
end

const function usage_error(summary: string, how_to_fix: string): never
	error(
		errors.usage_error(summary, {
			command = 'lutest setup',
			how_to_fix = how_to_fix,
		}),
		0
	)
end

const function read_default(
	prompt: Prompt,
	confirm: Confirm?,
	label: string,
	default: string
): string
	const message = `? {label} [{default}]: `
	const value = stringext.trim(prompt(message))
	const resolved = if value == '' then default else value
	if confirm ~= nil then confirm(message, resolved) end
	return resolved
end

const function read_positive_integer(
	prompt: Prompt,
	confirm: Confirm?,
	warn: Warn?,
	label: string
): number
	const message = `? {label}: `

	while true do
		const value = stringext.trim(prompt(message))
		const parsed = tonumber(value)
		if parsed ~= nil and parsed > 0 and parsed % 1 == 0 then
			if confirm ~= nil then confirm(message, value) end
			return parsed
		end

		if warn ~= nil then
			warn(`Invalid {label}. Enter a positive integer.`)
		end
	end
end

const function read_runtime(
	prompt: Prompt,
	confirm: Confirm?,
	warn: Warn?
): RuntimeSelection
	const message =
		'? Which runtimes do you want to configure? [lute/roblox/both]: '

	while true do
		const runtime = parse_runtime(prompt(message))
		if runtime ~= nil then
			if confirm ~= nil then confirm(message, runtime) end
			return runtime
		end

		if warn ~= nil then
			warn 'Invalid runtime selection. Choose `lute`, `roblox`, or `both`.'
		end
	end
end

const function quote_toml(value: string): string
	return `"{value:gsub('\\', '\\\\'):gsub('"', '\\"')}"`
end

const function render_config(config: SetupConfig): string
	const lines = {
		'[discovery]',
		'gitignore = true',
	} :: { string }

	if includes_lute(config.runtime) then
		table.insert(lines, '')
		table.insert(lines, '[discovery.lute]')
		table.insert(
			lines,
			`require = {quote_toml(config.lute_require :: string)}`
		)
		table.insert(
			lines,
			`roots = [{quote_toml(config.lute_root :: string)}]`
		)
	end

	if includes_roblox(config.runtime) then
		table.insert(lines, '')
		table.insert(lines, '[discovery.roblox]')
		table.insert(
			lines,
			`require = {quote_toml(config.roblox_require :: string)}`
		)
		table.insert(
			lines,
			`roots = [{quote_toml(config.roblox_root :: string)}]`
		)
		table.insert(lines, '')
		table.insert(lines, '[roblox]')
		table.insert(lines, `universe_id = {config.universe_id}`)
		table.insert(lines, `place_id = {config.place_id}`)
	end

	return `{table.concat(lines, '\n')}\n`
end

const function format_intro(): string
	return table.concat({
		tint.cyan.bold 'Lutest setup',
		tint.dim 'Create an initial lutest.toml for this project.',
	}, '\n')
end

const function format_confirmation(message: string, value: string): string
	const label = message:gsub('^%?%s*', '')
	return tint.green(`✓ {label}{value}`)
end

const function format_success(config: SetupConfig): string
	const lines = {
		tint.green.bold 'Created lutest.toml.',
	} :: { string }
	if not includes_roblox(config.runtime) then
		return table.concat(lines, '\n')
	end

	table.insert(lines, '')
	table.insert(lines, tint.magenta.bold 'Roblox')
	table.insert(
		lines,
		'Set ROBLOX_OPEN_CLOUD_API_KEY in your environment or .env before running tests.'
	)
	return table.concat(lines, '\n')
end

const function collect_config(
	prompt: Prompt,
	confirm: Confirm?,
	warn: Warn?
): SetupConfig
	const runtime = read_runtime(prompt, confirm, warn)
	const config = { runtime = runtime } :: SetupConfig

	if includes_lute(runtime) then
		config.lute_root = read_default(
			prompt,
			confirm,
			'Lute source root',
			DEFAULT_LUTE_ROOT
		)
		config.lute_require = read_default(
			prompt,
			confirm,
			'Lutest require path',
			DEFAULT_LUTE_REQUIRE
		)
	end

	if includes_roblox(runtime) then
		config.roblox_root = read_default(
			prompt,
			confirm,
			'Roblox source root',
			DEFAULT_ROBLOX_ROOT
		)
		config.roblox_require = read_default(
			prompt,
			confirm,
			'Lutest library path',
			DEFAULT_ROBLOX_REQUIRE
		)
		config.universe_id = read_positive_integer(
			prompt,
			confirm,
			warn,
			'Universe ID'
		)
		config.place_id =
			read_positive_integer(prompt, confirm, warn, 'Place ID')
	end

	return config
end

const function run()
	const config_path = path.join(process.cwd(), CONFIG_PATH)
	if fs.exists(config_path) then
		usage_error(
			'`lutest.toml` already exists.',
			'Edit the existing file or remove it before running `lutest setup`.'
		)
	end

	print(format_intro())
	print ''
	const is_tty = tty.stdout_is_tty()
	const config = collect_config(function(message: string): string
		return io.input(tint.cyan(message))
	end, function(message: string, value: string)
		if not is_tty then return end
		io.write(
			`\27[1A\r\27[2K{format_confirmation(message, value)}\n`
		)
	end, function(message: string)
		print(tint.yellow(`! {message}`))
	end)
	fs.writeStringToFile(config_path, render_config(config))
	print ''
	print(format_success(config))
end

t.test('should render a Lute-only configuration', function()
	const output = render_config {
		runtime = 'lute',
		lute_require = '@lutest_release',
		lute_root = 'src',
	}

	assert(output:find('[discovery.lute]', 1, true) ~= nil)
	assert(output:find('roots = ["src"]', 1, true) ~= nil)
	assert(output:find('[roblox]', 1, true) == nil)
end)

t.test('should render a Roblox configuration', function()
	const output = render_config {
		runtime = 'roblox',
		roblox_require = 'ReplicatedStorage.Packages.lutest',
		roblox_root = 'game',
		universe_id = 1,
		place_id = 2,
	}

	assert(output:find('[discovery.roblox]', 1, true) ~= nil)
	assert(output:find('universe_id = 1', 1, true) ~= nil)
	assert(output:find('place_id = 2', 1, true) ~= nil)
	assert(output:find('ROBLOX_OPEN_CLOUD_API_KEY', 1, true) == nil)
end)

t.test('should collect a complete Roblox configuration', function()
	const responses = {
		'roblox',
		'',
		'',
		'123',
		'456',
	}
	local index = 0
	const confirmed = {} :: { string }
	const config = collect_config(function(_: string): string
		index += 1
		return responses[index]
	end, function(_: string, value: string)
		table.insert(confirmed, value)
	end, nil)

	assert(config.runtime == 'roblox')
	assert(config.roblox_root == DEFAULT_ROBLOX_ROOT)
	assert(config.roblox_require == DEFAULT_ROBLOX_REQUIRE)
	assert(config.universe_id == 123)
	assert(config.place_id == 456)
	assert(#confirmed == 5)
	assert(confirmed[1] == 'roblox')
	assert(confirmed[5] == '456')
end)

t.test('should format a successful answer with a checkmark', function()
	const output = format_confirmation('? Universe ID: ', '123')

	assert(output:find('✓ Universe ID: 123', 1, true) ~= nil)
end)

t.test('should format Roblox setup guidance', function()
	const output = format_success {
		runtime = 'roblox',
		roblox_require = DEFAULT_ROBLOX_REQUIRE,
		roblox_root = DEFAULT_ROBLOX_ROOT,
		universe_id = 1,
		place_id = 2,
	}

	assert(output:find('Created lutest.toml.', 1, true) ~= nil)
	assert(output:find('ROBLOX_OPEN_CLOUD_API_KEY', 1, true) ~= nil)
end)

t.test('should accept all runtime selections', function()
	assert(parse_runtime 'lute' == 'lute')
	assert(parse_runtime 'Roblox' == 'roblox')
	assert(parse_runtime 'both' == 'both')
	assert(parse_runtime 'unknown' == nil)
end)

t.test('should repeat an invalid runtime selection with a warning', function()
	const responses = { 'unknown', 'roblox' }
	const warnings = {} :: { string }
	local index = 0
	const runtime = read_runtime(
		function(_: string): string
			index += 1
			return responses[index]
		end,
		nil,
		function(message: string)
			table.insert(warnings, message)
		end
	)

	assert(runtime == 'roblox')
	assert(index == 2)
	assert(#warnings == 1)
	assert(warnings[1]:find('Invalid runtime selection.', 1, true) ~= nil)
end)

t.test('should repeat an invalid Roblox ID with a warning', function()
	const responses = { 'sakm', '123' }
	const warnings = {} :: { string }
	local index = 0
	const universe_id = read_positive_integer(
		function(_: string): string
			index += 1
			return responses[index]
		end,
		nil,
		function(message: string)
			table.insert(warnings, message)
		end,
		'Universe ID'
	)

	assert(universe_id == 123)
	assert(index == 2)
	assert(#warnings == 1)
	assert(warnings[1]:find('Invalid Universe ID.', 1, true) ~= nil)
end)

return {
	run = run,
}
