export type TestSpec = {
	name: string,
	fn: () -> (),
}

export type TestResultMap = {
	passed: {
		name: string,
		passed: true,
	},
	failed: {
		name: string,
		passed: false,
		error_message: string,
	},
}

export type TestResultKind = keyof<TestResultMap>
export type PassedTestResult = index<TestResultMap, "passed">
export type FailedTestResult = index<TestResultMap, "failed">
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
	results: { TestResult },
}

export type TestRunner = {
	run: (suite: TestSuite) -> TestSuiteResult,
}

return nil
