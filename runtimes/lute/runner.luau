const luau = require '@std/luau'
const core = require '@core'

export type TestSuite = core.TestSuite
export type TestSuiteResult = core.TestSuiteResult

const function is_test_suite(value: unknown): boolean
	if typeof(value) ~= 'table' then return false end
	const candidate = value :: { name: unknown, tests: unknown }

	if typeof(candidate.name) ~= 'string' then return false end
	return typeof(candidate.tests) == 'table'
end

const function load_suites(path: string): { TestSuite }
	const loaded = luau.loadModule(path)
	if is_test_suite(loaded) then return { loaded :: TestSuite } end

	assert(
		typeof(loaded) == 'table',
		`expected '{path}' to return a test suite or array of test suites`
	)

	const suites = {} :: { TestSuite }

	for index, suite in loaded do
		assert(
			is_test_suite(suite),
			`expected suite #{index} from '{path}' to match the TestSuite contract`
		)

		table.insert(suites, suite :: TestSuite)
	end

	return suites
end

const function run_file(path: string): { TestSuiteResult }
	const suite_results = {} :: { TestSuiteResult }

	for _, suite in load_suites(path) do
		table.insert(suite_results, core.run(suite))
	end

	return suite_results
end

const function run_files(paths: { string }): { TestSuiteResult }
	const suite_results = {} :: { TestSuiteResult }

	for _, path in paths do
		for _, suite_result in run_file(path) do
			table.insert(suite_results, suite_result)
		end
	end

	return suite_results
end

return {
	run_file = run_file,
	run_files = run_files,
}
