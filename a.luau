const reporter = require '@core/reporter'
const lute = require '@runtimes/lute'

for _, suite_result in lute.run_file 'examples/lute_smoke.luau' do
	reporter.print_suite_result(suite_result)
end
