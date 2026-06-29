local types = require("@core/types")

export type TestSpec = types.TestSpec
export type TestResult = types.TestResult
export type TestSuite = types.TestSuite
export type TestSuiteResult = types.TestSuiteResult

local function run_test(test: TestSpec): TestResult
	local ok, result = pcall(test.fn :: any)

	if ok then
		return {
			name = test.name,
			passed = true,
		}
	end

	return {
		name = test.name,
		passed = false,
		error_message = tostring(result),
	}
end

local function run(suite: TestSuite): TestSuiteResult
	local results = {} :: { TestResult }
	local total_tests = #suite.tests
	local passed = 0

	for _, test in suite.tests do
		local test_result = run_test(test)
		table.insert(results, test_result)

		if test_result.passed then
			passed += 1
		end
	end

	return {
		name = suite.name,
		total_tests = total_tests,
		passed_tests = passed,
		failed_tests = total_tests - passed,
		results = results,
	}
end

return {
	run = run,
}
