const types = require '@self/types'
const runner = require '@self/runner'
const reporter = require '@self/reporter'

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

return {
	collect_run_result = reporter.collect_run_result,
	format_run_result = reporter.format_run_result,
	run = runner.run,
	print_run_result = reporter.print_run_result,
}
