const process = require '@std/process'
const errors = require '@core/errors'
const help = require '@self/help'
const reporter = require '@core/reporter'
const lute = require '@runtimes/lute'
const suggest = require '@lutest/utils/suggest'

const function collect_cli_args(): { string }
	const args = {} :: { string }

	for index = 2, #process.args do
		table.insert(args, process.args[index])
	end

	return args
end

type ParsedCommand = {
	kind: 'help' | 'test' | 'error',
	paths: { string }?,
	message: string?,
}

const function wants_help(args: { string }): boolean
	for _, arg in args do
		if arg == '-h' or arg == '--help' then return true end
	end

	return false
end

const function collect_paths(args: { string }, start_index: number): { string }
	const paths = {} :: { string }

	for index = start_index, #args do
		table.insert(paths, args[index])
	end

	return paths
end

const function parse_command(args: { string }): ParsedCommand
	if wants_help(args) then return {
		kind = 'help',
	} end

	const command = args[1]
	if command == nil then
		return {
			kind = 'error',
			message = errors.usage_error('Missing command.', {
				where = 'lutest',
				how_to_fix = 'Use `lutest test [paths...]` to run tests, or `lutest --help` to see available commands.',
			}),
		}
	end

	if command == 'test' then
		return {
			kind = 'test',
			paths = collect_paths(args, 2),
		}
	end

	const suggested_command = suggest.closest_match(command, {
		'test',
	})

	return {
		kind = 'error',
		message = errors.usage_error(`Unknown command '{command}'.`, {
			command = `lutest {command}`,
			highlight = command,
			suggestion = if suggested_command == nil
				then nil
				else `'{suggested_command}'`,
			how_to_fix = 'Use `lutest test [paths...]` to run tests, or `lutest --help` to see available commands.',
		}),
	}
end

const function has_failures(results: { reporter.TestSuiteResult }): boolean
	for _, result in results do
		if result.failed_tests > 0 then return true end
	end

	return false
end

const function print_lutest_error(message: string)
	print(errors.display_error(message))
end

const function main()
	const args = collect_cli_args()
	const command = parse_command(args)

	if command.kind == 'help' then
		help.print_help()
		process.exit(0)
	end

	if command.kind == 'error' then
		print_lutest_error(command.message :: string)
		print ''
		help.print_help()
		process.exit(1)
	end

	local results = nil :: { reporter.TestSuiteResult }?
	local runtime_error = nil :: string?
	const ok = xpcall(function()
		results = lute.run_discovered(command.paths :: { string })
	end, function(err)
		runtime_error = tostring(err)
		return runtime_error
	end)

	if not ok then
		const message = runtime_error :: string
		if errors.is_lutest_error(message) then
			print_lutest_error(message)
		else
			print_lutest_error(
				errors.internal_error(
					'The runner crashed while preparing test suites.',
					{
						where = 'runner',
						how_to_fix = 'This looks like a Lutest bug. Please report it with the command, project config, and stack trace below.',
						details = message,
					}
				)
			)
		end

		process.exit(1)
	end

	const resolved_results = results :: { reporter.TestSuiteResult }
	if #resolved_results == 0 then
		print_lutest_error(
			errors.usage_error('No test files were discovered.', {
				where = if #(
							command.paths :: { string }
						) > 0
					then `lutest test {table.concat(
						command.paths :: { string },
						' '
					)}`
					else 'lutest test',
				how_to_fix = 'Pass an existing test file or directory, or update `discovery.roots` in `lutest.toml`.',
			})
		)
		process.exit(1)
	end

	reporter.print_run_result(resolved_results)

	process.exit(if has_failures(resolved_results) then 1 else 0)
end

main()
