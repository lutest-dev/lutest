export type TestMode = 'run' | 'skip' | 'only' | 'todo'
export type TestFn = () -> ()

export type RunnableTestMode = 'run' | 'skip' | 'only'

export type RunnableTestSpec = {
	name: string,
	mode: RunnableTestMode,
	fn: TestFn,
}

export type TodoTestSpec = {
	name: string,
	mode: 'todo',
}

export type TestSpec = RunnableTestSpec | TodoTestSpec

export type TestResultMap = {
	passed: {
		name: string,
		kind: 'passed',
	},
	failed: {
		name: string,
		kind: 'failed',
		error_message: string,
	},
	skipped: {
		name: string,
		kind: 'skipped',
	},
	todo: {
		name: string,
		kind: 'todo',
	},
}

export type TestResultKind = keyof<TestResultMap>
export type PassedTestResult = index<TestResultMap, 'passed'>
export type FailedTestResult = index<TestResultMap, 'failed'>
export type SkippedTestResult = index<TestResultMap, 'skipped'>
export type TodoTestResult = index<TestResultMap, 'todo'>
export type TestResult = index<TestResultMap, TestResultKind>

export type TestSuite = {
	name: string,
	tests: { TestSpec },
}

export type TestSuiteResult = {
	name: string,
	total_tests: number,
	passed_tests: number,
	failed_tests: number,
	skipped_tests: number,
	todo_tests: number,
	results: { TestResult },
}

export type TestRunner = {
	run: (suite: TestSuite) -> TestSuiteResult,
}

return nil
