const errors = require '@core/errors'
const suggest = require '@lutest/utils/suggest'
const t = require '@lutest_release'

export type ParsedCommand = {
	kind: 'help' | 'test' | 'todo' | 'version' | 'error',
	paths: { string }?,
	message: string?,
}

const function collect_paths(args: { string }, start_index: number): { string }
	const paths = {} :: { string }

	for index = start_index, #args do
		table.insert(paths, args[index])
	end

	return paths
end

const function parse_command(args: { string }): ParsedCommand
	const command = args[1]
	if command == nil then
		return {
			kind = 'error',
			message = errors.usage_error('Missing command.', {
				where = 'lutest',
				how_to_fix = 'Use `lutest test [paths...]` to run tests, `lutest todo [paths...]` to list todo test cases, `lutest version` to see the current version, or `lutest help` to see available commands.',
			}),
		}
	end

	if command == 'test' then
		return {
			kind = 'test',
			paths = collect_paths(args, 2),
		}
	end

	if command == 'help' then return {
		kind = 'help',
	} end

	if command == 'todo' then
		return {
			kind = 'todo',
			paths = collect_paths(args, 2),
		}
	end

	if command == 'version' then return {
		kind = 'version',
	} end

	const suggested_command = suggest.closest_match(command, {
		'help',
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
			how_to_fix = 'Use `lutest test [paths...]` to run tests, `lutest todo [paths...]` to list todo test cases, `lutest version` to see the current version, or `lutest help` to see available commands.',
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
