const types = require '@core/types'
const registry = require '@self/registry'
const context = require '@self/context'
const t = require '@lutest_release'

export type TestSpec = types.TestSpec
export type TestMode = types.TestMode
export type HookFn = types.HookFn
export type SuiteHooks = types.SuiteHooks
export type TestScope = types.TestScope

local active_scope = nil :: TestScope?

const function is_collecting(): boolean
	return context.get_register() ~= nil or registry.is_active()
end

const function is_running(): boolean
	return context.is_running()
end

const function scope_or_error(): TestScope
	const scope = active_scope
	if scope ~= nil then return scope end

	error('Hooks can only be registered inside t.suite().', 2)
end

const function register_spec(spec: TestSpec)
	if not is_collecting() then return end
	if context.register(spec) then return end

	registry.register(spec)
end

const function test(name: string, fn: () -> ()): TestSpec
	const spec = {
		name = name,
		mode = 'run',
		fn = fn,
		scope = active_scope,
	}

	register_spec(spec)
	return spec
end

const function skip(name: string, fn: () -> ()): TestSpec
	const spec = {
		name = name,
		mode = 'skip',
		fn = fn,
		scope = active_scope,
	}

	register_spec(spec)
	return spec
end

const function only(name: string, fn: () -> ()): TestSpec
	const spec = {
		name = name,
		mode = 'only',
		fn = fn,
		scope = active_scope,
	}

	register_spec(spec)
	return spec
end

const function todo(name: string): TestSpec
	const spec = {
		name = name,
		mode = 'todo',
		scope = active_scope,
	}

	register_spec(spec)
	return spec
end

const function suite(name: string, register: () -> ())
	if not is_collecting() then return end
	if active_scope ~= nil then
		error('Nested t.suite() calls are not supported.', 2)
	end

	const scope = {
		name = name,
		hooks = {
			before_all = {},
			before_each = {},
			after_each = {},
			after_all = {},
		},
	} :: TestScope

	active_scope = scope
	const ok, result = (pcall :: any)(register)
	active_scope = nil
	if not ok then error(result, 0) end
end

const function before_all(hook: HookFn)
	if not is_collecting() then return end
	table.insert(scope_or_error().hooks.before_all, hook)
end

const function before_each(hook: HookFn)
	if not is_collecting() then return end
	table.insert(scope_or_error().hooks.before_each, hook)
end

const function after_each(hook: HookFn)
	if not is_collecting() then return end
	table.insert(scope_or_error().hooks.after_each, hook)
end

const function after_all(hook: HookFn)
	if not is_collecting() then return end
	table.insert(scope_or_error().hooks.after_all, hook)
end

t.test('should keep test definitions inert outside collection', function()
	local suite_called = false

	test('run test', function() end)
	skip('skip test', function() end)
	only('only test', function() end)
	todo 'todo test'
	before_all(function() end)
	before_each(function() end)
	after_each(function() end)
	after_all(function() end)
	suite('ignored suite', function()
		suite_called = true
	end)

	assert(suite_called == false)
end)

t.test('should return the created spec from each public helper', function()
	const run_fn = function() end
	const skip_fn = function() end
	const only_fn = function() end

	const run_spec = test('run test', run_fn)
	const skip_spec = skip('skip test', skip_fn)
	const only_spec = only('only test', only_fn)
	const todo_spec = todo 'todo test'

	assert(run_spec.name == 'run test')
	assert(run_spec.mode == 'run')
	if run_spec.mode == 'run' then assert(run_spec.fn == run_fn) end

	assert(skip_spec.name == 'skip test')
	assert(skip_spec.mode == 'skip')
	if skip_spec.mode == 'skip' then assert(skip_spec.fn == skip_fn) end

	assert(only_spec.name == 'only test')
	assert(only_spec.mode == 'only')
	if only_spec.mode == 'only' then assert(only_spec.fn == only_fn) end

	assert(todo_spec.name == 'todo test')
	assert(todo_spec.mode == 'todo')
end)

t.test('should reject hooks outside a suite during collection', function()
	const previous_hook = context.get_register()
	context.clear_register()
	registry.clear()
	registry.begin 'active-module'

	const ok, message = pcall(function()
		before_each(function() end)
	end)

	context.set_register(previous_hook)
	registry.clear()

	assert(ok == false)
	assert(tostring(message):find('inside t.suite()', 1, true) ~= nil)
end)

const api = {
	--- Registers a test that runs normally while Lutest is collecting a test suite.
	---
	--- @param name string -- Test name shown in reports.
	--- @param fn () -> () -- Callback run as the test body.
	--- @return TestSpec -- Registered test specification.
	test = test,
	--- Registers a test that is skipped while Lutest is collecting a test suite.
	---
	--- @param name string -- Test name shown in reports.
	--- @param fn () -> () -- Test callback, which is not run.
	--- @return TestSpec -- Registered test specification.
	skip = skip,
	--- Registers a focused test while Lutest is collecting a test suite.
	---
	--- Focused tests run while normal tests in the same run are skipped.
	--- @param name string -- Test name shown in reports.
	--- @param fn () -> () -- Callback run as the test body.
	--- @return TestSpec -- Registered test specification.
	only = only,
	--- Registers a planned test while Lutest is collecting a test suite.
	---
	--- @param name string -- Test name shown in reports.
	--- @return TestSpec -- Registered todo specification without a test body.
	todo = todo,
	--- Groups tests and lifecycle hooks under `name` while Lutest is collecting a test suite.
	---
	--- @param name string -- Suite name shown in reports.
	--- @param register () -> () -- Callback that synchronously registers tests and hooks.
	--- Does nothing outside collection. Nested suites are not supported.
	suite = suite,
	--- Registers a hook that runs once before the suite's tests during collection.
	---
	--- @param hook HookFn -- Callback run before all suite tests.
	--- Does nothing outside collection. Must be called inside a suite callback while collecting.
	before_all = before_all,
	--- Registers a hook that runs before each suite test during collection.
	---
	--- @param hook HookFn -- Callback run before each suite test.
	--- Does nothing outside collection. Must be called inside a suite callback while collecting.
	before_each = before_each,
	--- Registers a hook that runs after each suite test during collection.
	---
	--- @param hook HookFn -- Callback run after each suite test.
	--- Does nothing outside collection. Must be called inside a suite callback while collecting.
	after_each = after_each,
	--- Registers a hook that runs once after the suite's tests during collection.
	---
	--- @param hook HookFn -- Callback run after all suite tests.
	--- Does nothing outside collection. Must be called inside a suite callback while collecting.
	after_all = after_all,
	--- Returns whether code is executing in an active Lutest session.
	---
	--- This is true while Lutest collects a suite and while it runs hooks or test callbacks.
	--- @return boolean -- Whether the current code runs under Lutest.
	is_running = is_running,
}

return api
