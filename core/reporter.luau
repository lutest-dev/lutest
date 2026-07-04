const types = require '@core/types'
const tint = require '@packages/tint'
const t = require '@lutest_release'

export type TestSuiteResult = types.TestSuiteResult
export type FailedTestResult = types.FailedTestResult

type RunResult = {
	total_tests: number,
	passed_tests: number,
	failed_tests: number,
	skipped_tests: number,
	todo_tests: number,
}

const function failed_test(
	name: string,
	error_message: string
): FailedTestResult
	return {
		name = name,
		kind = 'failed',
		error_message = error_message,
	}
end

const function suite_result(
	name: string,
	run_result: RunResult,
	results: { types.TestResult }?
): TestSuiteResult
	return {
		name = name,
		total_tests = run_result.total_tests,
		passed_tests = run_result.passed_tests,
		failed_tests = run_result.failed_tests,
		skipped_tests = run_result.skipped_tests,
		todo_tests = run_result.todo_tests,
		results = results or {},
	}
end

const function format_counts(result: RunResult): string
	return `{result.total_tests} total  {tint.green(
		`{result.passed_tests} pass`
	)}  {tint.red(`{result.failed_tests} fail`)}  {tint.yellow(
		`{result.skipped_tests} skip`
	)}  {tint.magenta(`{result.todo_tests} todo`)}`
end

const function collect_run_result(results: { TestSuiteResult }): RunResult
	local total_tests = 0
	local passed_tests = 0
	local failed_tests = 0
	local skipped_tests = 0
	local todo_tests = 0

	for _, result in results do
		total_tests += result.total_tests
		passed_tests += result.passed_tests
		failed_tests += result.failed_tests
		skipped_tests += result.skipped_tests
		todo_tests += result.todo_tests
	end

	return {
		total_tests = total_tests,
		passed_tests = passed_tests,
		failed_tests = failed_tests,
		skipped_tests = skipped_tests,
		todo_tests = todo_tests,
	}
end

const function append_failed_details(
	lines: { string },
	suite_result: TestSuiteResult
)
	for _, test_result in suite_result.results do
		if test_result.kind ~= 'failed' then continue end

		const failed = test_result :: FailedTestResult
		table.insert(lines, tint.red(failed.name))
		table.insert(lines, failed.error_message)
		table.insert(lines, '')
	end
end

const function format_run_result(results: { TestSuiteResult }): string
	const run_result = collect_run_result(results)
	const run_status = if run_result.failed_tests == 0
		then tint.green.bold 'OK'
		else tint.red.bold 'FAIL'
	const summary = `{run_status}  {format_counts(run_result)}`

	if run_result.failed_tests == 0 then return summary end
	const lines = { summary, '' }

	for _, suite_result in results do
		append_failed_details(lines, suite_result)
	end

	return table.concat(lines, '\n')
end

const function print_run_result(results: { TestSuiteResult })
	print(format_run_result(results))
end

t.test('should format aggregated run results in one line', function()
	const output = format_run_result {
		suite_result('core/runner.luau', {
			total_tests = 5,
			passed_tests = 5,
			failed_tests = 0,
			skipped_tests = 0,
			todo_tests = 0,
		}),
		suite_result('runtimes/lute/discovery.luau', {
			total_tests = 11,
			passed_tests = 2,
			failed_tests = 0,
			skipped_tests = 0,
			todo_tests = 9,
		}),
	}

	assert(output:find('OK', 1, true) ~= nil)
	assert(output:find('16 total', 1, true) ~= nil)
	assert(output:find('7 pass', 1, true) ~= nil)
	assert(output:find('0 fail', 1, true) ~= nil)
	assert(output:find('0 skip', 1, true) ~= nil)
	assert(output:find('9 todo', 1, true) ~= nil)
	assert(output:find('suite:', 1, true) == nil)
	assert(output:find('\n', 1, true) == nil)
end)

t.test('should keep failed test details in aggregated output', function()
	const output = format_run_result {
		suite_result('runtimes/lute/runner.luau', {
			total_tests = 1,
			passed_tests = 0,
			failed_tests = 1,
			skipped_tests = 0,
			todo_tests = 0,
		}, {
			failed_test('should fail', 'boom'),
		}),
	}

	assert(output:find('FAIL', 1, true) ~= nil)
	assert(output:find('should fail', 1, true) ~= nil)
	assert(output:find('boom', 1, true) ~= nil)
	assert(output:find('1 total', 1, true) ~= nil)
	assert(output:find('1 fail', 1, true) ~= nil)
	assert(output:find('runtimes/lute/runner.luau ::', 1, true) == nil)
end)

t.test('should aggregate skipped counts across suites', function()
	const output = format_run_result {
		suite_result('core/runner.luau', {
			total_tests = 2,
			passed_tests = 1,
			failed_tests = 0,
			skipped_tests = 1,
			todo_tests = 0,
		}),
		suite_result('runtimes/lute/discovery.luau', {
			total_tests = 3,
			passed_tests = 1,
			failed_tests = 0,
			skipped_tests = 1,
			todo_tests = 1,
		}),
	}

	assert(output:find('OK', 1, true) ~= nil)
	assert(output:find('5 total', 1, true) ~= nil)
	assert(output:find('2 pass', 1, true) ~= nil)
	assert(output:find('0 fail', 1, true) ~= nil)
	assert(output:find('2 skip', 1, true) ~= nil)
	assert(output:find('1 todo', 1, true) ~= nil)
	assert(output:find('\n', 1, true) == nil)
end)

t.test('should keep failed details in order across suites', function()
	const output = format_run_result {
		suite_result('first-suite', {
			total_tests = 1,
			passed_tests = 0,
			failed_tests = 1,
			skipped_tests = 0,
			todo_tests = 0,
		}, {
			failed_test('first failure', 'first boom'),
		}),
		suite_result('second-suite', {
			total_tests = 1,
			passed_tests = 0,
			failed_tests = 1,
			skipped_tests = 0,
			todo_tests = 0,
		}, {
			failed_test('second failure', 'second boom'),
		}),
	}

	const first_name_index = output:find('first failure', 1, true)
	const first_error_index = output:find('first boom', 1, true)
	const second_name_index = output:find('second failure', 1, true)
	const second_error_index = output:find('second boom', 1, true)

	assert(output:find('FAIL', 1, true) ~= nil)
	assert(first_name_index ~= nil)
	assert(first_error_index ~= nil)
	assert(second_name_index ~= nil)
	assert(second_error_index ~= nil)
	assert(first_name_index < first_error_index)
	assert(first_error_index < second_name_index)
	assert(second_name_index < second_error_index)
end)

t.test('should format an empty run summary', function()
	const output = format_run_result {}

	assert(output:find('OK', 1, true) ~= nil)
	assert(output:find('0 total', 1, true) ~= nil)
	assert(output:find('0 pass', 1, true) ~= nil)
	assert(output:find('0 fail', 1, true) ~= nil)
	assert(output:find('0 skip', 1, true) ~= nil)
	assert(output:find('0 todo', 1, true) ~= nil)
	assert(output:find('\n', 1, true) == nil)
end)

t.test('should omit non-failed details from failed output', function()
	const output = format_run_result {
		suite_result('mixed-suite', {
			total_tests = 4,
			passed_tests = 1,
			failed_tests = 1,
			skipped_tests = 1,
			todo_tests = 1,
		}, {
			{
				name = 'passed marker',
				kind = 'passed',
			},
			failed_test('failed marker', 'boom'),
			{
				name = 'skipped marker',
				kind = 'skipped',
			},
			{
				name = 'todo marker',
				kind = 'todo',
			},
		}),
	}

	assert(output:find('FAIL', 1, true) ~= nil)
	assert(output:find('failed marker', 1, true) ~= nil)
	assert(output:find('boom', 1, true) ~= nil)
	assert(output:find('passed marker', 1, true) == nil)
	assert(output:find('skipped marker', 1, true) == nil)
	assert(output:find('todo marker', 1, true) == nil)
end)

return {
	collect_run_result = collect_run_result,
	format_run_result = format_run_result,
	print_run_result = print_run_result,
}
