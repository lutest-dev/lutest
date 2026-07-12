const errors = require '@core/errors'
const suggest = require '@lutest/utils/suggest'
const t = require '@lutest_release'

export type ParsedCommand = {
	kind: 'help' | 'setup' | 'test' | 'todo' | 'version' | 'error',
	paths: { string }?,
	runtime: 'lute' | 'roblox'?,
	message: string?,
}

const SUPPORTED_RUNTIMES = {
	lute = true,
	roblox = true,
}

const function collect_command_arguments(
	args: { string },
	start_index: number
): ({ string }, 'lute' | 'roblox'?)
	const paths = {} :: { string }
	local runtime = nil :: ('lute' | 'roblox')?

	local index = start_index
	while index <= #args do
		const argument = args[index]
		local runtime_value = nil :: string?

		if argument == '--runtime' then
			if index == #args then
				error(
					errors.usage_error(
						'Missing value for `--runtime`.',
						{
							command = 'lutest test --runtime',
							highlight = '--runtime',
							how_to_fix = 'Use `--runtime lute` or `--runtime roblox`.',
						}
					),
					0
				)
			end
			runtime_value = args[index + 1]
			index += 1
		elseif argument:sub(1, 10) == '--runtime=' then
			runtime_value = argument:sub(11)
		end

		if runtime_value ~= nil then
			if runtime ~= nil then
				error(
					errors.usage_error(
						'`--runtime` may only be provided once.',
						{
							command = `lutest test {argument}`,
							highlight = argument,
							how_to_fix = 'Choose one runtime: `lute` or `roblox`.',
						}
					),
					0
				)
			end
			if not SUPPORTED_RUNTIMES[runtime_value] then
				error(
					errors.usage_error(
						`Unknown runtime '{runtime_value}'.`,
						{
							command = `lutest test {argument}`,
							highlight = runtime_value,
							how_to_fix = 'Use `--runtime lute` or `--runtime roblox`.',
						}
					),
					0
				)
			end

			runtime = runtime_value :: 'lute' | 'roblox'
			index += 1
			continue
		end

		if argument:sub(1, 2) == '--' then
			error(
				errors.usage_error(
					`Unknown option '{argument}'.`,
					{
						command = `lutest test {argument}`,
						highlight = argument,
						how_to_fix = 'Use `--runtime lute` or `--runtime roblox`.',
					}
				),
				0
			)
		end

		table.insert(paths, argument)
		index += 1
	end

	return paths, runtime
end

const function parse_command(args: { string }): ParsedCommand
	if #args == 0 then
		return {
			kind = 'error',
			message = errors.usage_error('Missing command.', {
				where = 'lutest',
				how_to_fix = 'Use `lutest setup` to create a config, `lutest test [paths...]` to run tests, `lutest todo [paths...]` to list todo test cases, `lutest version` to see the current version, or `lutest help` to see available commands.',
			}),
		}
	end

	const command = args[1]

	if command == 'setup' then
		if #args == 1 then return { kind = 'setup' } end
		return {
			kind = 'error',
			message = errors.usage_error(
				'`setup` does not accept arguments.',
				{
					command = `lutest {table.concat(
						args,
						' '
					)}`,
					how_to_fix = 'Run `lutest setup` without arguments.',
				}
			),
		}
	end

	if command == 'test' or command == 'todo' then
		local paths = nil :: { string }?
		local runtime = nil :: ('lute' | 'roblox')?
		local parse_error = nil :: string?
		const ok = xpcall(function()
			paths, runtime = collect_command_arguments(args, 2)
		end, function(err)
			parse_error = tostring(err)
			return parse_error
		end)
		if not ok then
			return {
				kind = 'error',
				message = parse_error,
			}
		end

		return {
			kind = command,
			paths = paths,
			runtime = runtime or 'lute',
		}
	end

	if command == 'help' then return {
		kind = 'help',
	} end

	if command == 'version' then return {
		kind = 'version',
	} end

	const suggested_command = suggest.closest_match(command, {
		'help',
		'setup',
		'test',
		'todo',
		'version',
	})

	return {
		kind = 'error',
		message = errors.usage_error(`Unknown command '{command}'.`, {
			command = `lutest {command}`,
			highlight = command,
			suggestion = if suggested_command == nil
				then nil
				else `'{suggested_command}'`,
			how_to_fix = 'Use `lutest setup` to create a config, `lutest test [paths...]` to run tests, `lutest todo [paths...]` to list todo test cases, `lutest version` to see the current version, or `lutest help` to see available commands.',
		}),
	}
end

t.test('should reject help flags', function()
	const command = parse_command {
		'--help',
	}
	const message = errors.strip_ansi(
		errors.display_error(command.message :: string)
	)

	assert(command.kind == 'error')
	assert(command.message ~= nil)
	assert(message:find('Unknown command \'--help\'.', 1, true) ~= nil)
end)

t.test('should parse help subcommand as help', function()
	const command = parse_command {
		'help',
	}

	assert(command.kind == 'help')
end)

t.test('should parse version subcommand as version', function()
	const command = parse_command {
		'version',
	}

	assert(command.kind == 'version')
end)

t.test('should parse setup without arguments', function()
	const command = parse_command { 'setup' }

	assert(command.kind == 'setup')
end)

t.test('should reject setup arguments', function()
	const command = parse_command { 'setup', 'roblox' }

	assert(command.kind == 'error')
	assert(
		(command.message :: string):find(
			'`setup` does not accept arguments.',
			1,
			true
		) ~= nil
	)
end)

t.test('should parse todo subcommand paths', function()
	const command = parse_command {
		'todo',
		'core',
	}

	assert(command.kind == 'todo')
	assert(command.paths ~= nil)
	assert(#(command.paths :: { string }) == 1)
	assert((command.paths :: { string })[1] == 'core')
end)

t.test('should parse test subcommand paths', function()
	const command = parse_command {
		'test',
		'core',
		'utils',
	}

	assert(command.kind == 'test')
	assert(command.paths ~= nil)
	assert(#(command.paths :: { string }) == 2)
	assert((command.paths :: { string })[1] == 'core')
	assert((command.paths :: { string })[2] == 'utils')
	assert(command.runtime == 'lute')
end)

t.test('should parse an explicit Roblox runtime', function()
	const command = parse_command {
		'test',
		'src',
		'--runtime=roblox',
	}
	assert(command.kind == 'test')
	assert(command.runtime == 'roblox')
	assert(#(command.paths :: { string }) == 1)
end)

t.test('should reject an unknown runtime', function()
	const command = parse_command {
		'test',
		'--runtime',
		'other',
	}
	assert(command.kind == 'error')
	assert(
		(command.message :: string):find('Unknown runtime', 1, true)
			~= nil
	)
end)

t.test('should suggest help for unknown commands when closest', function()
	const command = parse_command {
		'hlp',
	}
	const message = errors.strip_ansi(
		errors.display_error(command.message :: string)
	)

	assert(command.kind == 'error')
	assert(command.message ~= nil)
	assert(message:find('Did you mean \'help\'?', 1, true) ~= nil)
end)

return {
	parse_command = parse_command,
}
