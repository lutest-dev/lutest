export type TestSpec = {
	name: string,
	fn: () -> (),
}

export type PassedTestResult = {
	name: string,
	passed: true,
}

export type FailedTestResult = {
	name: string,
	passed: false,
	error_message: string,
}

export type TestResult = PassedTestResult | FailedTestResult

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
