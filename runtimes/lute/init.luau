const core = require '@core'
const config = require '@runtimes/lute/config'
const discovery = require '@runtimes/lute/discovery'
const runner = require '@runtimes/lute/runner'
const t = require '@lutest_release'

export type TestSuite = core.TestSuite
export type TestSuiteResult = core.TestSuiteResult
export type LutestConfig = config.LutestConfig
export type TestSpec = core.TestSpec

const api = {
	discover_files = discovery.discover_files,
	collect_suites = runner.collect_suites,
	load_config = config.load_config,
	run_file = runner.run_file,
	run_files = runner.run_files,
	run_discovered = runner.run_discovered,
}

t.test('should expose lute runtime public entrypoints', function()
	assert(api.discover_files == discovery.discover_files)
	assert(api.collect_suites == runner.collect_suites)
	assert(api.load_config == config.load_config)
	assert(api.run_file == runner.run_file)
	assert(api.run_files == runner.run_files)
	assert(api.run_discovered == runner.run_discovered)
end)

return api
