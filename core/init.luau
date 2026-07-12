const types = require '@self/types'
const runner = require '@self/runner'
const t = require '@lutest_release'

export type TestSpec = types.TestSpec
export type TestMode = types.TestMode
export type RunnableTestMode = types.RunnableTestMode
export type RunnableTestSpec = types.RunnableTestSpec
export type TodoTestSpec = types.TodoTestSpec
export type PassedTestResult = types.PassedTestResult
export type FailedTestResult = types.FailedTestResult
export type SkippedTestResult = types.SkippedTestResult
export type TodoTestResult = types.TodoTestResult
export type TestResult = types.TestResult
export type TestSuite = types.TestSuite
export type TestSuiteResult = types.TestSuiteResult
export type TestRunner = types.TestRunner

const api = {
	run = runner.run,
}

t.test('should expose the runner public entrypoint', function()
	assert(api.run == runner.run)
end)

return api
