const core = require '@core'
const discovery = require '@runtimes/lute/discovery'
const runner = require '@runtimes/lute/runner'

export type TestSuite = core.TestSuite
export type TestSuiteResult = core.TestSuiteResult

return {
	discover_files = discovery.discover_files,
	run_file = runner.run_file,
	run_files = runner.run_files,
	run_discovered = runner.run_discovered,
}
