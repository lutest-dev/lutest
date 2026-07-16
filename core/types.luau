export type TestMode = 'run' | 'skip' | 'only' | 'todo'
export type TestFn = () -> ()
export type HookFn = () -> ()

export type SuiteHooks = {
	before_all: { HookFn },
	before_each: { HookFn },
	after_each: { HookFn },
	after_all: { HookFn },
}

export type TestScope = {
	name: string,
	hooks: SuiteHooks,
}

export type RunnableTestMode = 'run' | 'skip' | 'only'

export type RunnableTestSpec = {
	name: string,
	mode: RunnableTestMode,
	fn: TestFn,
	scope: TestScope?,
}

export type TodoTestSpec = {
	name: string,
	mode: 'todo',
	scope: TestScope?,
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

export type LifecycleFailure = {
	suite_name: string,
	hook_name: string,
	error_message: string,
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
	warnings: { string }?,
}

export type TestSuiteResult = {
	name: string,
	total_tests: number,
	passed_tests: number,
	failed_tests: number,
	skipped_tests: number,
	todo_tests: number,
	results: { TestResult },
	lifecycle_failures: { LifecycleFailure }?,
	warnings: { string }?,
}

export type TestRunner = {
	run: (suite: TestSuite) -> TestSuiteResult,
}

return nil
