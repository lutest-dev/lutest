const reporter = require '@self/reporter'
const t = require '@lutest_release'

export type TodoTest = {
	name: string,
	mode: 'todo',
}

export type TodoSuite = {
	name: string,
	tests: { TodoTest },
}

const function collect_remote_todo_suites(
	results: { reporter.TestSuiteResult }
): (
	{ TodoSuite },
	{ reporter.TestSuiteResult }
)
	const todo_suites = {} :: { TodoSuite }
	const failures = {} :: { reporter.TestSuiteResult }

	for _, suite in results do
		if suite.failed_tests > 0 then
			table.insert(failures, suite)
			continue
		end

		const tests = {} :: { TodoTest }
		for _, result in suite.results do
			if result.kind ~= 'todo' then continue end

			table.insert(
				tests,
				{
					name = result.name,
					mode = 'todo',
				} :: TodoTest
			)
		end

		if #tests > 0 then
			table.insert(todo_suites, {
				name = suite.name,
				tests = tests,
			})
		end
	end

	return todo_suites, failures
end

t.test('should retain remote suite load failures', function()
	const todos, failures = collect_remote_todo_suites {
		{
			name = 'game/broken.luau',
			total_tests = 1,
			passed_tests = 0,
			failed_tests = 1,
			skipped_tests = 0,
			todo_tests = 0,
			results = {
				{
					name = 'load test suite',
					kind = 'failed',
					error_message = 'boom',
				},
			},
		},
		{
			name = 'game/todos.luau',
			total_tests = 1,
			passed_tests = 0,
			failed_tests = 0,
			skipped_tests = 0,
			todo_tests = 1,
			results = {
				{
					name = 'ship feature',
					kind = 'todo',
				},
			},
		},
	}

	assert(#failures == 1)
	const failed_result = failures[1].results[1]
	assert(failed_result.kind == 'failed')
	if failed_result.kind == 'failed' then
		assert(failed_result.error_message == 'boom')
	end
	assert(#todos == 1)
	assert(todos[1].tests[1].name == 'ship feature')
end)

return {
	collect_remote_todo_suites = collect_remote_todo_suites,
}
