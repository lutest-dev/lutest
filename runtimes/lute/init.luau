const core = require '@core'
const discovery = require '@self/discovery'
const runner = require '@self/runner'

export type TestSuite = core.TestSuite
export type TestSuiteResult = core.TestSuiteResult

return {
	discover_files = discovery.discover_files,
	run_file = runner.run_file,
	run_files = runner.run_files,
}
