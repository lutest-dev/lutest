const errors = require '@core/errors'
const suggest = require '@lutest/utils/suggest'
const t = require '@lutest_release'

export type ParsedCommand = {
	kind: 'help'
		| 'doctor'
		| 'install-package'
		| 'setup'
		| 'test'
		| 'todo'
		| 'version'
		| 'error',
	paths: { string }?,
	runtime: 'lute' | 'roblox'?,
	config_path: string?,
	dry_run: boolean?,
	output: string?,
	message: string?,
}

const SUPPORTED_RUNTIMES = {
	lute = true,
	roblox = true,
}

const function collect_command_arguments(
	args: { string },
	start_index: number
): (
	{ string },
	'lute' | 'roblox'?,
	string?,
	boolean
)
	const paths = {} :: { string }
	local runtime = nil :: ('lute' | 'roblox')?
	local config_path = nil :: string?
	local dry_run = false

	local index = start_index
	while index <= #args do
		const argument = args[index]
		if argument == '--dry-run' then
			if dry_run then
				error(
					errors.usage_error '`--dry-run` may only be provided once.',
					0
				)
			end

			dry_run = true
			index += 1
			continue
		end

		local runtime_value = nil :: string?
		local config_value = nil :: string?

		if argument == '--runtime' then
			if index == #args then
				error(
					errors.usage_error 'Missing value for `--runtime`.',
					0
				)
			end
			runtime_value = args[index + 1]
			index += 1
		elseif argument:sub(1, 10) == '--runtime=' then
			runtime_value = argument:sub(11)
		elseif argument == '--config' then
			if index == #args then
				error(
					errors.usage_error 'Missing value for `--config`.',
					0
				)
			end
			config_value = args[index + 1]
			index += 1
		elseif argument:sub(1, 9) == '--config=' then
			config_value = argument:sub(10)
		end

		if runtime_value ~= nil then
			if runtime ~= nil then
				error(
					errors.usage_error '`--runtime` may only be provided once.',
					0
				)
			end
			if not SUPPORTED_RUNTIMES[runtime_value] then
				error(
					errors.usage_error(
						`Unknown runtime '{runtime_value}'.`
					),
					0
				)
			end

			runtime = runtime_value :: 'lute' | 'roblox'
			index += 1
			continue
		end

		if config_value ~= nil then
			if config_path ~= nil then
				error(
					errors.usage_error '`--config` may only be provided once.',
					0
				)
			end
			if config_value == '' then
				error(
					errors.usage_error 'Missing value for `--config`.',
					0
				)
			end

			config_path = config_value
			index += 1
			continue
		end

		if argument:sub(1, 2) == '--' then
			error(
				errors.usage_error(
					`Unknown option '{argument}'.`
				),
				0
			)
		end

		table.insert(paths, argument)
		index += 1
	end

	return paths, runtime, config_path, dry_run
end

const function parse_command(args: { string }): ParsedCommand
	if #args == 0 then
		return {
			kind = 'error',
			message = errors.usage_error 'Missing command.',
		}
	end

	const command = args[1]

	if command == 'setup' then
		if #args == 1 then return { kind = 'setup' } end
		return {
			kind = 'error',
			message = errors.usage_error '`setup` does not accept arguments.',
		}
	end

	if command == 'install-package' then
		if #args == 1 then return { kind = 'install-package' } end

		const output = args[2]
		if #args == 3 and output == '--output' and args[3] ~= '' then
			return {
				kind = 'install-package',
				output = args[3],
			}
		end
		if
			#args == 2
			and output:sub(1, 9) == '--output='
			and #output > 9
		then
			return {
				kind = 'install-package',
				output = output:sub(10),
			}
		end

		return {
			kind = 'error',
			message = errors.usage_error 'Invalid `install-package` arguments.',
		}
	end

	if command == 'doctor' then
		local paths = nil :: { string }?
		local runtime = nil :: ('lute' | 'roblox')?
		local config_path = nil :: string?
		local dry_run = false
		local parse_error = nil :: string?
		const ok = xpcall(function()
			paths, runtime, config_path, dry_run =
				collect_command_arguments(args, 2)
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
		if #(paths :: { string }) > 0 or runtime ~= nil or dry_run then
			return {
				kind = 'error',
				message = errors.usage_error '`doctor` only accepts `--config <path>`.',
			}
		end

		return {
			kind = 'doctor',
			config_path = config_path,
		}
	end

	if command == 'test' or command == 'todo' then
		local paths = nil :: { string }?
		local runtime = nil :: ('lute' | 'roblox')?
		local config_path = nil :: string?
		local dry_run = false
		local parse_error = nil :: string?
		const ok = xpcall(function()
			paths, runtime, config_path, dry_run =
				collect_command_arguments(args, 2)
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
			runtime = runtime,
			config_path = config_path,
			dry_run = dry_run,
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
		'doctor',
		'install-package',
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

t.test('should parse doctor with an explicit configuration path', function()
	const command = parse_command {
		'doctor',
		'--config',
		'configs/roblox.toml',
	}

	assert(command.kind == 'doctor')
	assert(command.config_path == 'configs/roblox.toml')
end)

t.test('should reject doctor test options', function()
	const command = parse_command { 'doctor', '--runtime', 'roblox' }

	assert(command.kind == 'error')
	assert(
		(command.message :: string):find(
			'`doctor` only accepts `--config <path>`.',
			1,
			true
		) ~= nil
	)
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

t.test('should parse an explicit package output directory', function()
	const command = parse_command {
		'install-package',
		'--output',
		'src/Packages',
	}

	assert(command.kind == 'install-package')
	assert(command.output == 'src/Packages')
end)

t.test('should reject invalid package arguments', function()
	const command = parse_command { 'install-package', 'lutest' }

	assert(command.kind == 'error')
	assert(
		(command.message :: string):find(
			'Invalid `install-package` arguments.',
			1,
			true
		) ~= nil
	)
end)

t.test('should reject an empty package output directory', function()
	const command = parse_command { 'install-package', '--output=' }

	assert(command.kind == 'error')
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
	assert(command.runtime == nil)
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

t.test('should parse a config path for test commands', function()
	const command = parse_command {
		'todo',
		'game',
		'--config',
		'configs/roblox.toml',
	}

	assert(command.kind == 'todo')
	assert(command.config_path == 'configs/roblox.toml')
	assert(#(command.paths :: { string }) == 1)
end)

t.test('should parse a dry run for test commands', function()
	const command = parse_command {
		'test',
		'game',
		'--runtime',
		'roblox',
		'--dry-run',
	}

	assert(command.kind == 'test')
	assert(command.runtime == 'roblox')
	assert(command.dry_run == true)
end)

t.test('should reject repeated dry run options', function()
	const command = parse_command {
		'todo',
		'--dry-run',
		'--dry-run',
	}

	assert(command.kind == 'error')
	assert(
		(command.message :: string):find(
			'`--dry-run` may only be provided once.',
			1,
			true
		) ~= nil
	)
end)

t.test('should reject a missing config path', function()
	const command = parse_command { 'test', '--config=' }

	assert(command.kind == 'error')
	assert(
		(command.message :: string):find(
			'Missing value for `--config`.',
			1,
			true
		) ~= nil
	)
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
