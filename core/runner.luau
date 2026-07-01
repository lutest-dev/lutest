const types = require '@core/types'

export type TestSpec = types.TestSpec
export type TestResult = types.TestResult
export type TestSuite = types.TestSuite
export type TestSuiteResult = types.TestSuiteResult

type RunOptions = {
	focus_only: boolean,
}

const function has_only_tests(tests: { TestSpec }): boolean
	for _, test in tests do
		if test.mode == 'only' then return true end
	end

	return false
end

const function should_skip_for_focus(
	test: TestSpec,
	options: RunOptions
): boolean
	if not options.focus_only then return false end
	if test.mode == 'only' then return false end
	if test.mode == 'todo' then return false end

	return true
end

const function run_test(test: TestSpec): TestResult
	if test.mode == 'skip' then
		return {
			name = test.name,
			kind = 'skipped',
		}
	end

	if test.mode == 'todo' then
		return {
			name = test.name,
			kind = 'todo',
		}
	end

	const ok: boolean, result = (pcall :: any)(function()
		test.fn()
	end)

	if ok then return {
		name = test.name,
		kind = 'passed',
	} end

	return {
		name = test.name,
		kind = 'failed',
		error_message = tostring(result),
	}
end

const function run(suite: TestSuite, options: RunOptions?): TestSuiteResult
	const results = {} :: { TestResult }
	const total_tests = #suite.tests
	local passed = 0
	local failed = 0
	local skipped = 0
	local todo = 0
	const resolved_options = options
		or {
			focus_only = has_only_tests(suite.tests),
		}

	for _, test in suite.tests do
		const test_result = if should_skip_for_focus(
				test,
				resolved_options
			)
			then {
				name = test.name,
				kind = 'skipped',
			} :: TestResult
			else run_test(test)

		table.insert(results, test_result)

		if test_result.kind == 'passed' then
			passed += 1
			continue
		end

		if test_result.kind == 'failed' then
			failed += 1
			continue
		end

		if test_result.kind == 'skipped' then
			skipped += 1
			continue
		end

		todo += 1
	end

	return {
		name = suite.name,
		total_tests = total_tests,
		passed_tests = passed,
		failed_tests = failed,
		skipped_tests = skipped,
		todo_tests = todo,
		results = results,
	}
end

return {
	run = run,
}
