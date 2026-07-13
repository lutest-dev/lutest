const process = require '@std/process'
const errors = require '@core/errors'
const command = require '@self/command'
const help = require '@self/help'
const install_package = require '@self/install_package'
const setup = require '@self/setup'
const version = require '@self/version'
const reporter = require '@self/reporter'
const todo = require '@self/todo'
const lute = require '@runtimes/lute'
const config = require '@runtimes/lute/config'
const roblox = require '@runtimes/roblox'

type TodoTest = todo.TodoTest
type TodoSuite = todo.TodoSuite

const function collect_cli_args(): { string }
	const args = {} :: { string }

	for index = 2, #process.args do
		table.insert(args, process.args[index])
	end

	return args
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

const function collect_todo_suites(paths: { string }): { TodoSuite }
	local todo_suites = {} :: { TodoSuite }

	for _, suite in lute.collect_suites(lute.discover_files(paths)) do
		const todo_tests = {} :: { TodoTest }

		for _, test in suite.tests do
			if test.mode ~= 'todo' then continue end

			table.insert(
				todo_tests,
				{
					name = test.name,
					mode = 'todo',
				} :: TodoTest
			)
		end

		if #todo_tests == 0 then continue end

		table.insert(todo_suites, {
			name = suite.name,
			tests = todo_tests,
		})
	end

	return todo_suites
end

const function main()
	const args = collect_cli_args()
	const parsed_command = command.parse_command(args)

	if parsed_command.kind == 'help' then
		help.print_help()
		process.exit(0)
	end

	if parsed_command.kind == 'version' then
		version.print_version()
		process.exit(0)
	end

	if parsed_command.kind == 'error' then
		print_lutest_error(parsed_command.message :: string)
		print ''
		help.print_help()
		process.exit(1)
	end

	local results = nil :: { reporter.TestSuiteResult }?
	local todo_suites = nil :: { TodoSuite }?
	local runtime_error = nil :: string?
	const ok = xpcall(function()
		if parsed_command.kind == 'install-package' then
			install_package.run(parsed_command.output)
			return
		end

		if parsed_command.kind == 'setup' then
			setup.run()
			return
		end

		if parsed_command.kind == 'todo' then
			const runtime = parsed_command.runtime
				or config.default_runtime(
					config.load_project_config()
				)
			if runtime == 'roblox' then
				const remote_results = roblox.run(
					parsed_command.paths :: { string },
					'todo'
				) :: { reporter.TestSuiteResult }
				const remote_todos, failures =
					todo.collect_remote_todo_suites(
						remote_results
					)
				if #failures > 0 then
					reporter.print_run_result(failures)
					process.exit(1)
				end
				todo_suites = remote_todos
				return
			end
			todo_suites = collect_todo_suites(
				parsed_command.paths :: { string }
			)
			return
		end

		const runtime = parsed_command.runtime
			or config.default_runtime(config.load_project_config())
		if runtime == 'roblox' then
			results = roblox.run(
				parsed_command.paths :: { string },
				'test'
			) :: any
			return
		end

		results =
			lute.run_discovered(parsed_command.paths :: { string })
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
					'Lutest stopped unexpectedly',
					{
						where = 'runner',
						how_to_fix = 'Report this with the details below.',
						details = message,
					}
				)
			)
		end

		process.exit(1)
	end

	if parsed_command.kind == 'todo' then
		reporter.print_todo_result(todo_suites :: { TodoSuite })
		process.exit(0)
	end

	if parsed_command.kind == 'setup' then process.exit(0) end
	if parsed_command.kind == 'install-package' then process.exit(0) end

	const resolved_results = results :: { reporter.TestSuiteResult }
	if #resolved_results == 0 then
		print_lutest_error(errors.usage_error('No test files found', {
			how_to_fix = 'Add a test file or update discovery.roots in lutest.toml.',
		}))
		process.exit(1)
	end

	reporter.print_run_result(resolved_results)

	process.exit(if has_failures(resolved_results) then 1 else 0)
end

main()
