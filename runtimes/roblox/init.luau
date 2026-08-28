const bundle = require '@self/bundle'
const credentials = require '@self/credentials'
const debug = require '@self/debug'
const discovery = require '@self/discovery'
const harness = require '@self/harness'
const open_cloud = require '@self/open_cloud'
const output = require '@self/output'
const progress = require '@self/progress'
const protocol = require '@self/protocol'
const rojo = require '@self/rojo'
const config = require '@runtimes/lute/config'
const process = require '@std/process'
const t = require '@lutest_release'

export type TestSuiteResult = protocol.TestSuiteResult

-- The generated suite wrapper starts the original source on line 4.
local SUITE_SOURCE_LINE_OFFSET = 3

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

const function supplied_library_root(): string?
	const root = process.env.LUTEST_ROBLOX_LIBRARY_ROOT
	if type(root) ~= 'string' or root == '' then return nil end
	return root
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
			lifecycle_failures = {},
		}
		table.insert(results, result)
	end
	return results
end

const function normalize_source_path(value: string): string
	local normalized = value:gsub('^LutestBundle%.', '')
	normalized = normalized:gsub('%.luau$', '')
	normalized = normalized:gsub('%.lua$', '')
	return (normalized:gsub('%.', '/'))
end

const function source_matches_suite(source: string, suite_path: string): boolean
	const normalized_source = normalize_source_path(source)
	const normalized_suite = normalize_source_path(suite_path)
	if normalized_source == normalized_suite then return true end
	return normalized_source:sub(-#normalized_suite - 1)
		== `/{normalized_suite}`
end

const function remap_error_line(
	error_message: string,
	suite_path: string
): string
	const source, line, details = error_message:match '^(.-):(%d+):(.*)$'
	if source == nil or line == nil or details == nil then
		return error_message
	end
	if not source_matches_suite(source, suite_path) then
		return error_message
	end

	const remote_line = tonumber(line) :: number
	if remote_line <= SUITE_SOURCE_LINE_OFFSET then return error_message end
	return `{source}:{remote_line - SUITE_SOURCE_LINE_OFFSET}:{details}`
end

const function remap_result_lines(results: { TestSuiteResult })
	for _, suite_result in results do
		for _, test_result in suite_result.results do
			if test_result.kind ~= 'failed' then continue end
			const error_message =
				test_result.error_message :: string
			test_result.error_message = remap_error_line(
				error_message,
				suite_result.name
			)
		end

		for _, failure in suite_result.lifecycle_failures or {} do
			failure.error_message = remap_error_line(
				failure.error_message,
				suite_result.name
			)
		end
	end
end

const function discover_files(
	paths: { string },
	config_path: string?
): { string }
	const discovery_config = (config.load_roblox_config(config_path))
	return discovery.discover_suites(paths, discovery_config, config_path)
end

const function inspect_bundle(paths: { string }, config_path: string?): string
	return debug.inspect(paths, config_path, supplied_library_root())
end

const function run(
	paths: { string },
	mode: 'test' | 'todo',
	config_path: string?
): { TestSuiteResult }
	const discovery_config, roblox_config =
		config.load_roblox_config(config_path)
	const suites =
		discovery.discover_suites(paths, discovery_config, config_path)
	if #suites == 0 then return {} end

	const all_files =
		discovery.discover_all_files({}, discovery_config, config_path)
	const project_files = rojo.map_files(
		bundle_files(all_files),
		roblox_config.rojo_project,
		config_path
	)
	const suite_paths = bundle.test_suite_paths(project_files, suites)
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
				project_files,
				suites,
				supplied_library_root()
			),
			harness.generate {
				require_path = `game.{discovery_config.require}`,
				test_paths = suite_paths,
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
	remap_result_lines(results)
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

t.test('should remap lines from wrapped Roblox suites', function()
	const suite_path =
		'ServerScriptService/services/machine/machine_service'
	const results = {
		{
			name = suite_path,
			total_tests = 1,
			passed_tests = 0,
			failed_tests = 1,
			skipped_tests = 0,
			todo_tests = 0,
			results = {
				{
					name = 'should buy an upgrade',
					kind = 'failed',
					error_message = `{suite_path}:82: Expected 2, got 4`,
				},
			},
			lifecycle_failures = {},
		},
	} :: { TestSuiteResult }

	remap_result_lines(results)
	assert(
		(results[1].results[1].error_message :: string)
			== `{suite_path}:79: Expected 2, got 4`
	)
end)

t.test('should preserve dependency error lines', function()
	const suite_path =
		'ServerScriptService/services/machine/machine_service'
	const results = {
		{
			name = suite_path,
			total_tests = 1,
			passed_tests = 0,
			failed_tests = 1,
			skipped_tests = 0,
			todo_tests = 0,
			results = {
				{
					name = 'should buy an upgrade',
					kind = 'failed',
					error_message = 'ServerScriptService/services/shop/shop_service:82: boom',
				},
			},
			lifecycle_failures = {},
		},
	} :: { TestSuiteResult }

	remap_result_lines(results)
	assert(
		(results[1].results[1].error_message :: string)
			== 'ServerScriptService/services/shop/shop_service:82: boom'
	)
end)

return {
	discover_files = discover_files,
	inspect_bundle = inspect_bundle,
	non_interactive_prefix = output.non_interactive_prefix,
	run = run,
}
