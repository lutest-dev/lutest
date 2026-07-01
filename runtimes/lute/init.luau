const core = require '@core'
const config = require '@runtimes/lute/config'
const discovery = require '@runtimes/lute/discovery'
const runner = require '@runtimes/lute/runner'

export type TestSuite = core.TestSuite
export type TestSuiteResult = core.TestSuiteResult
export type LutestConfig = config.LutestConfig

return {
	discover_files = discovery.discover_files,
	load_config = config.load_config,
	run_file = runner.run_file,
	run_files = runner.run_files,
	run_discovered = runner.run_discovered,
}
