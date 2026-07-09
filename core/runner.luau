const types = require '@core/types'
const path_utils = require '@lutest/utils/path'
const t = require '@lutest_release'

export type TestSpec = types.TestSpec
export type TestResult = types.TestResult
export type TestSuite = types.TestSuite
export type TestSuiteResult = types.TestSuiteResult
export type FailedTestResult = types.FailedTestResult

type RunOptions = {
	focus_only: boolean,
}

const function runnable_test_spec(
	name: string,
	mode: 'run' | 'skip' | 'only',
	fn: () -> ()
): TestSpec
	return {
		name = name,
		mode = mode,
		fn = fn,
	}
end

const function todo_test_spec(name: string): TestSpec
	return {
		name = name,
		mode = 'todo',
	}
end

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

const function shorten_workspace_paths(message: string): string
	const normalized_cwd = path_utils.cwd()
	const backslash_cwd = normalized_cwd:gsub('/', '\\')

	local shortened = message
	shortened = shortened:gsub(normalized_cwd .. '/', '')
	shortened = shortened:gsub(backslash_cwd .. '\\', '')

	return shortened
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
		error_message = shorten_workspace_paths(tostring(result)),
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

t.test('should focus on only tests', function()
	local ran_non_only = false
	local ran_only = false

	const run_test_spec = runnable_test_spec('run test', 'run', function()
		ran_non_only = true
	end)

	const only_test_spec = runnable_test_spec(
		'only test',
		'only',
		function()
			ran_only = true
		end
	)

	const result = run {
		name = 'suite',
		tests = { run_test_spec, only_test_spec },
	}

	assert(ran_non_only == false)
	assert(ran_only == true)
	assert(result.results[1].kind == 'skipped')
	assert(result.results[2].kind == 'passed')
	assert(result.skipped_tests == 1)
	assert(result.passed_tests == 1)
end)

t.test('should keep todo tests as todo under only focus', function()
	const only_test_spec = runnable_test_spec(
		'only test',
		'only',
		function() end
	)

	const todo_spec = todo_test_spec 'todo test'

	const result = run {
		name = 'suite',
		tests = { only_test_spec, todo_spec },
	}

	assert(result.results[1].kind == 'passed')
	assert(result.results[2].kind == 'todo')
	assert(result.todo_tests == 1)
end)

t.test('should count mixed results correctly', function()
	local ran_passed = false
	local ran_skipped = false

	const passed_test_spec = runnable_test_spec(
		'passed test',
		'run',
		function()
			ran_passed = true
		end
	)

	const failed_test_spec = runnable_test_spec(
		'failed test',
		'run',
		function(): ()
			error 'boom'
		end
	)

	const skipped_test_spec = runnable_test_spec(
		'skipped test',
		'skip',
		function()
			ran_skipped = true
		end
	)

	const todo_spec = todo_test_spec 'todo test'

	const tests = {
		passed_test_spec,
		failed_test_spec,
		skipped_test_spec,
		todo_spec,
	}

	const result = run({
		name = 'suite',
		tests = tests,
	}, { focus_only = false })

	assert(ran_passed == true)
	assert(ran_skipped == false)
	assert(result.total_tests == 4)
	assert(result.passed_tests == 1)
	assert(result.failed_tests == 1)
	assert(result.skipped_tests == 1)
	assert(result.todo_tests == 1)
end)

t.test('should preserve result order', function()
	const first_test_spec = runnable_test_spec(
		'first test',
		'run',
		function() end
	)

	const second_test_spec = runnable_test_spec(
		'second test',
		'skip',
		function() end
	)

	const third_test_spec = todo_test_spec 'third test'

	const result = run({
		name = 'suite',
		tests = { first_test_spec, second_test_spec, third_test_spec },
	}, { focus_only = false })

	assert(result.results[1].name == 'first test')
	assert(result.results[1].kind == 'passed')
	assert(result.results[2].name == 'second test')
	assert(result.results[2].kind == 'skipped')
	assert(result.results[3].name == 'third test')
	assert(result.results[3].kind == 'todo')
end)

t.test('should capture thrown errors as failed results', function()
	const failing_test_spec = runnable_test_spec(
		'failing test',
		'run',
		function(): ()
			error 'boom'
		end
	)

	const result = run({
		name = 'suite',
		tests = { failing_test_spec },
	}, { focus_only = false })

	assert(result.results[1].kind == 'failed')
	assert(result.failed_tests == 1)
	const failed_result = result.results[1] :: FailedTestResult
	assert(failed_result.error_message:find('boom', 1, true) ~= nil)
end)

t.test('should shorten workspace paths in failed error messages', function()
	const cwd = path_utils.cwd()
	const result = run({
		name = 'suite',
		tests = {
			runnable_test_spec(
				'failing test',
				'run',
				function(): ()
					error(
						`{cwd}/core/errors.luau:205: assertion failed!`
					)
				end
			),
		},
	}, { focus_only = false })

	const failed_result = result.results[1] :: FailedTestResult
	assert(
		failed_result.error_message:find(
			'core/errors.luau:205: assertion failed!',
			1,
			true
		) ~= nil
	)
	assert(failed_result.error_message:find(cwd, 1, true) == nil)
end)

return {
	run = run,
}
