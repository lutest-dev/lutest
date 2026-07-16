const types = require '@core/types'

export type TestSpec = types.TestSpec
export type TestResult = types.TestResult
export type TestSuite = types.TestSuite
export type TestSuiteResult = types.TestSuiteResult
export type LifecycleFailure = types.LifecycleFailure
export type TestScope = types.TestScope

type RunOptions = {
	focus_only: boolean,
}

const function has_only_tests(tests: { TestSpec }): boolean
	for _, test in tests do
		if test.mode == 'only' then return true end
	end

	return false
end

const function is_focus_skipped(test: TestSpec, options: RunOptions): boolean
	if not options.focus_only then return false end
	if test.mode == 'only' or test.mode == 'todo' then return false end

	return true
end

const function failed_result(name: string, messages: { string }): TestResult
	return {
		name = name,
		kind = 'failed',
		error_message = table.concat(messages, '\n'),
	}
end

const function test_name(test: TestSpec): string
	const scope = test.scope
	if scope == nil then return test.name end

	return `{scope.name} > {test.name}`
end

const function run_hook(hook: types.HookFn, name: string): string?
	const ok, result = pcall(hook)
	if ok then return nil end

	return `{name}: {tostring(result)}`
end

const function run_test(test: TestSpec, scope: TestScope?): TestResult
	if test.mode == 'skip' then
		return { name = test_name(test), kind = 'skipped' }
	end
	if test.mode == 'todo' then
		return { name = test_name(test), kind = 'todo' }
	end

	const messages = {} :: { string }
	if scope ~= nil then
		for _, hook in scope.hooks.before_each do
			const failure = run_hook(hook, 'before_each')
			if failure ~= nil then
				table.insert(messages, failure)
			end
		end
	end

	if #messages == 0 then
		const ok, result = pcall(test.fn)
		if not ok then table.insert(messages, tostring(result)) end
	end

	if scope ~= nil then
		for index = #scope.hooks.after_each, 1, -1 do
			const failure = run_hook(
				scope.hooks.after_each[index],
				'after_each'
			)
			if failure ~= nil then
				table.insert(messages, failure)
			end
		end
	end

	if #messages == 0 then
		return { name = test_name(test), kind = 'passed' }
	end
	return failed_result(test_name(test), messages)
end

const function append_result(
	results: { TestResult },
	counts: { [string]: number },
	result: TestResult
)
	table.insert(results, result)
	counts[result.kind] += 1
end

const function run_scope(
	tests: { TestSpec },
	scope: TestScope?,
	options: RunOptions,
	results: { TestResult },
	counts: { [string]: number },
	lifecycle_failures: { LifecycleFailure }
)
	local has_runnable = false
	for _, test in tests do
		if test.mode == 'todo' or test.mode == 'skip' then continue end
		if not is_focus_skipped(test, options) then
			has_runnable = true
		end
	end

	local setup_failed = false
	if scope ~= nil and has_runnable then
		for _, hook in scope.hooks.before_all do
			const failure = run_hook(hook, 'before_all')
			if failure == nil then continue end
			setup_failed = true
			table.insert(lifecycle_failures, {
				suite_name = scope.name,
				hook_name = 'before_all',
				error_message = failure,
			})
			break
		end
	end

	for _, test in tests do
		if is_focus_skipped(test, options) or test.mode == 'skip' then
			append_result(
				results,
				counts,
				{ name = test_name(test), kind = 'skipped' }
			)
			continue
		end
		if test.mode == 'todo' then
			append_result(
				results,
				counts,
				{ name = test_name(test), kind = 'todo' }
			)
			continue
		end
		if setup_failed then
			append_result(
				results,
				counts,
				{ name = test_name(test), kind = 'skipped' }
			)
			continue
		end

		append_result(results, counts, run_test(test, scope))
	end

	if scope == nil or not has_runnable then return end
	for index = #scope.hooks.after_all, 1, -1 do
		const failure =
			run_hook(scope.hooks.after_all[index], 'after_all')
		if failure == nil then continue end
		table.insert(lifecycle_failures, {
			suite_name = scope.name,
			hook_name = 'after_all',
			error_message = failure,
		})
	end
end

const function run(suite: TestSuite, options: RunOptions?): TestSuiteResult
	const resolved_options = options
		or {
			focus_only = has_only_tests(suite.tests),
		}
	const results = {} :: { TestResult }
	const counts = { passed = 0, failed = 0, skipped = 0, todo = 0 }
	const lifecycle_failures = {} :: { LifecycleFailure }
	local group = {} :: { TestSpec }
	local active_scope = nil :: TestScope?

	const flush_group = function()
		if #group == 0 then return end
		run_scope(
			group,
			active_scope,
			resolved_options,
			results,
			counts,
			lifecycle_failures
		)
		group = {}
	end

	for _, test in suite.tests do
		if test.scope == active_scope then
			table.insert(group, test)
			continue
		end

		flush_group()
		active_scope = test.scope
		table.insert(group, test)
	end
	flush_group()

	return {
		name = suite.name,
		total_tests = #suite.tests,
		passed_tests = counts.passed,
		failed_tests = counts.failed,
		skipped_tests = counts.skipped,
		todo_tests = counts.todo,
		results = results,
		lifecycle_failures = lifecycle_failures,
		warnings = suite.warnings,
	}
end

return {
	has_only_tests = has_only_tests,
	run = run,
}
