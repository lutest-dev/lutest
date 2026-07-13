const types = require '@core/types'
const ui = require '@lutest/utils/ui'
const t = require '@lutest_release'

export type TestSuiteResult = types.TestSuiteResult
export type FailedTestResult = types.FailedTestResult
type TodoSuite = {
	name: string,
	tests: { types.TodoTestSpec },
}

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

const function test_label(count: number): string
	return if count == 1 then 'test' else 'tests'
end

const function format_summary(result: RunResult): string
	if result.failed_tests > 0 then
		return ui.failed(
			`{result.failed_tests} of {result.total_tests} {test_label(
				result.total_tests
			)} failed`
		)
	end

	if result.skipped_tests > 0 or result.todo_tests > 0 then
		local parts = {
			ui.passed(
				`{result.passed_tests} {test_label(
					result.passed_tests
				)} passed`
			),
		}
		if result.skipped_tests > 0 then
			table.insert(
				parts,
				ui.warning(`{result.skipped_tests} skipped`)
			)
		end
		if result.todo_tests > 0 then
			table.insert(parts, ui.todo(`{result.todo_tests} todo`))
		end
		return table.concat(parts, '  ')
	end

	return ui.passed(
		`{result.passed_tests} {test_label(result.passed_tests)} passed`
	)
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
		const source_line, message =
			failed.error_message:match '^.-:(%d+):%s*(.*)$'
		const location = if source_line == nil
			then suite_result.name
			else `{suite_result.name}:{source_line}`
		const displayed_error = if message == nil
				or message == ''
			then failed.error_message
			else message
		table.insert(lines, ui.section(failed.name))
		table.insert(lines, `  {ui.muted(location)}`)
		table.insert(lines, `  {displayed_error:gsub('\n', '\n  ')}`)
		table.insert(lines, '')
	end
end

const function format_run_result(results: { TestSuiteResult }): string
	const run_result = collect_run_result(results)
	const summary = format_summary(run_result)

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

const function collect_todo_count(todo_suites: { TodoSuite }): number
	local todo_count = 0

	for _, suite in todo_suites do
		todo_count += #suite.tests
	end

	return todo_count
end

const function format_todo_result(todo_suites: { TodoSuite }): string
	const todo_count = collect_todo_count(todo_suites)

	if todo_count == 0 then return ui.passed 'No todo tests' end

	local lines = {
		ui.todo.bold(`> {todo_count} todo {test_label(todo_count)}`),
	} :: { string }

	for _, suite in todo_suites do
		table.insert(lines, '')
		table.insert(lines, ui.section(suite.name))

		for _, test in suite.tests do
			table.insert(lines, `  {ui.todo '-'} {test.name}`)
		end
	end

	return table.concat(lines, '\n')
end

const function print_todo_result(todo_suites: { TodoSuite })
	print(format_todo_result(todo_suites))
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
	const plain_output = output:gsub('\27%[[0-9;]*m', '')

	assert(plain_output ~= '')
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

	assert(output:find('x 1 of 1 test failed', 1, true) ~= nil)
	assert(output:find('should fail', 1, true) ~= nil)
	assert(output:find('boom', 1, true) ~= nil)
	assert(output:find('> should fail', 1, true) ~= nil)
	assert(output:find('runtimes/lute/runner.luau', 1, true) ~= nil)
end)

t.test(
	'should show a source line once for location-prefixed failures',
	function()
		const output = format_run_result {
			suite_result('src/a.luau', {
				total_tests = 1,
				passed_tests = 0,
				failed_tests = 1,
				skipped_tests = 0,
				todo_tests = 0,
			}, {
				failed_test(
					'should fail',
					'LutestBundle.src.a:6: expected true'
				),
			}),
		}

		assert(output:find('src/a.luau:6', 1, true) ~= nil)
		assert(output:find('expected true', 1, true) ~= nil)
		assert(output:find('LutestBundle', 1, true) == nil)
	end
)

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

	assert(output:find('+ 2 tests passed', 1, true) ~= nil)
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

	assert(output:find('x 2 of 2 tests failed', 1, true) ~= nil)
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

	assert(output:find('+ 0 tests passed', 1, true) ~= nil)
	assert(output:find('0 failed', 1, true) == nil)
	assert(output:find('0 skipped', 1, true) == nil)
	assert(output:find('0 todo', 1, true) == nil)
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

	assert(output:find('x 1 of 4 tests failed', 1, true) ~= nil)
	assert(output:find('failed marker', 1, true) ~= nil)
	assert(output:find('boom', 1, true) ~= nil)
	assert(output:find('passed marker', 1, true) == nil)
	assert(output:find('skipped marker', 1, true) == nil)
	assert(output:find('todo marker', 1, true) == nil)
end)

t.test('should format a todo list grouped by suite', function()
	const output = format_todo_result {
		{
			name = 'cli/reporter.luau',
			tests = {
				{
					name = 'should show nested suite summaries',
					mode = 'todo',
				},
				{
					name = 'should support compact failure grouping',
					mode = 'todo',
				},
			},
		},
		{
			name = 'runtimes/lute/discovery.luau',
			tests = {
				{
					name = 'should support glob roots',
					mode = 'todo',
				},
			},
		},
	}
	const plain_output = output:gsub('\27%[[0-9;]*m', '')

	assert(plain_output ~= '')
end)

t.test(
	'should avoid repeating the pass count for an all-passing run',
	function()
		const output = format_run_result {
			suite_result('core/runner.luau', {
				total_tests = 2,
				passed_tests = 2,
				failed_tests = 0,
				skipped_tests = 0,
				todo_tests = 0,
			}),
		}

		assert(output:find('+ 2 tests passed', 1, true) ~= nil)
	end
)

t.test('should format an empty todo list compactly', function()
	const output = format_todo_result {}

	assert(output:find('+ No todo tests', 1, true) ~= nil)
end)

return {
	collect_run_result = collect_run_result,
	format_run_result = format_run_result,
	format_todo_result = format_todo_result,
	print_run_result = print_run_result,
	print_todo_result = print_todo_result,
}
