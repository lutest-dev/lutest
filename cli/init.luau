const process = require '@std/process'
const help = require '@self/help'
const reporter = require '@core/reporter'
const lute = require '@runtimes/lute'

const function collect_cli_args(): { string }
	const args = {} :: { string }

	for index = 2, #process.args do
		table.insert(args, process.args[index])
	end

	return args
end

const function wants_help(args: { string }): boolean
	for _, arg in args do
		if arg == '-h' or arg == '--help' then return true end
	end

	return false
end

const function has_failures(results: { reporter.TestSuiteResult }): boolean
	for _, result in results do
		if result.failed_tests > 0 then return true end
	end

	return false
end

const function main()
	const args = collect_cli_args()

	if wants_help(args) then
		help.print_help()
		process.exit(0)
	end

	const results = lute.run_discovered(args)
	if #results == 0 then
		print 'no test modules found'
		process.exit(1)
	end

	reporter.print_run_result(results)

	process.exit(if has_failures(results) then 1 else 0)
end

main()
