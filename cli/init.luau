const process = require '@std/process'
const errors = require '@core/errors'
const command = require '@self/command'
const doctor = require '@self/doctor'
const help = require '@self/help'
const install_package = require '@self/install_package'
const setup = require '@self/setup'
const version = require '@self/version'
const reporter = require '@self/reporter'
const todo = require '@self/todo'
const lute = require '@runtimes/lute'
const config = require '@runtimes/lute/config'
const roblox = require '@runtimes/roblox'

type TodoTest = reporter.TodoTest
type TodoSuite = reporter.TodoSuite

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
		if #(result.lifecycle_failures or {}) > 0 then return true end
	end

	return false
end

const function print_lutest_error(message: string)
	print(errors.display_error(message))
end

const function collect_todo_suites(
	paths: { string },
	config_path: string?
): { TodoSuite }
	local todo_suites = {} :: { TodoSuite }

	for _, suite in
		lute.collect_suites(
			lute.discover_files(paths, config_path),
			config_path
		)
	do
		const todo_tests = {} :: { TodoTest }

		for _, test in suite.tests do
			if test.mode ~= 'todo' then continue end
			const scope = test.scope
			const name = if scope == nil
				then test.name
				else `{scope.name} > {test.name}`

			table.insert(
				todo_tests,
				{
					name = name,
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

const function discover_dry_run_files(
	paths: { string },
	runtime: 'lute' | 'roblox',
	config_path: string?
): { string }
	if runtime == 'roblox' then
		return roblox.discover_files(paths, config_path)
	end

	return lute.discover_files(paths, config_path)
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
	local dry_run_files = nil :: { string }?
	local dry_run_runtime = nil :: ('lute' | 'roblox')?
	local doctor_report = nil :: doctor.DoctorReport?
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

		if parsed_command.kind == 'doctor' then
			doctor_report = doctor.run(parsed_command.config_path)
			return
		end

		const runtime = parsed_command.runtime
			or config.default_runtime(
				config.load_project_config(
					parsed_command.config_path
				)
			)
		if parsed_command.dry_run then
			dry_run_files = discover_dry_run_files(
				parsed_command.paths :: { string },
				runtime,
				parsed_command.config_path
			)
			dry_run_runtime = runtime
			return
		end

		if parsed_command.kind == 'todo' then
			if runtime == 'roblox' then
				const remote_results = roblox.run(
					parsed_command.paths :: { string },
					'todo',
					parsed_command.config_path
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
				parsed_command.paths :: { string },
				parsed_command.config_path
			)
			return
		end

		if runtime == 'roblox' then
			results = roblox.run(
				parsed_command.paths :: { string },
				'test',
				parsed_command.config_path
			) :: any
			return
		end

		results = lute.run_discovered(
			parsed_command.paths :: { string },
			parsed_command.config_path
		)
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

	if doctor_report ~= nil then
		const report = doctor_report :: doctor.DoctorReport
		print(report.output)
		process.exit(if report.ready then 0 else 1)
	end

	if dry_run_files ~= nil then
		reporter.print_dry_run(
			dry_run_runtime :: 'lute' | 'roblox',
			parsed_command.config_path,
			dry_run_files
		)
		process.exit(if #dry_run_files == 0 then 1 else 0)
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
