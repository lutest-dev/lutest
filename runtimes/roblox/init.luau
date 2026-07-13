const bundle = require '@self/bundle'
const credentials = require '@self/credentials'
const discovery = require '@self/discovery'
const harness = require '@self/harness'
const open_cloud = require '@self/open_cloud'
const progress = require '@self/progress'
const protocol = require '@self/protocol'
const config = require '@runtimes/lute/config'
const t = require '@lutest_release'

export type TestSuiteResult = protocol.TestSuiteResult

const function bundle_files(paths: { string }): { bundle.BundleFile }
	const files = {} :: { bundle.BundleFile }
	for _, absolute in paths do
		const file: bundle.BundleFile = {
			absolute = absolute,
			relative = (discovery.relative_paths { absolute })[1],
		}
		table.insert(files, file)
	end
	return files
end

const function load_failures_as_results(
	failures: { protocol.LoadFailure }
): { TestSuiteResult }
	const results = {} :: { TestSuiteResult }
	for _, failure in failures do
		const test_result: protocol.TestResult = {
			name = `load test suite: {failure.path}`,
			kind = 'failed',
			error_message = failure.error_message,
		}
		const result: TestSuiteResult = {
			name = failure.path,
			total_tests = 1,
			passed_tests = 0,
			failed_tests = 1,
			skipped_tests = 0,
			todo_tests = 0,
			results = { test_result },
		}
		table.insert(results, result)
	end
	return results
end

const function run(
	paths: { string },
	mode: 'test' | 'todo'
): { TestSuiteResult }
	const discovery_config, roblox_config = config.load_roblox_config()
	const suites = discovery.discover_suites(paths, discovery_config)
	if #suites == 0 then return {} end

	const all_files = discovery.discover_all_files(
		discovery_config.roots,
		discovery_config
	)
	const current_progress = progress.default_progress()
	current_progress.update 'preparing bundle'

	local completed = nil :: open_cloud.CompletedTask?
	local run_error = nil :: string?
	const ok = xpcall(function()
		completed = open_cloud.run(
			open_cloud.default_client(),
			roblox_config,
			credentials.load(),
			bundle.build(
				bundle_files(all_files),
				discovery.relative_paths(suites)
			),
			harness.generate {
				require_path = `game.{discovery_config.require}`,
				test_paths = discovery.relative_paths(suites),
				mode = mode,
			},
			current_progress.update
		)
	end, function(err)
		run_error = tostring(err)
		return run_error
	end)
	current_progress.finish()
	if not ok then error(run_error, 0) end

	const decoded = protocol.decode_logs(
		(completed :: open_cloud.CompletedTask).logs
	)
	const results = decoded.results
	for _, load_result in load_failures_as_results(decoded.load_failures) do
		table.insert(results, load_result)
	end
	return results
end

t.test('should map a suite load failure to a failed reporter result', function()
	const results = load_failures_as_results {
		{
			path = 'src/broken.luau',
			error_message = 'boom',
		},
	}
	assert(results[1].failed_tests == 1)
	assert(results[1].results[1].name == 'load test suite: src/broken.luau')
	assert(results[1].results[1].error_message == 'boom')
end)

return {
	run = run,
}
