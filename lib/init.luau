const types = require '@core/types'
const registry = require '@self/registry'
const context = require '@self/context'
const t = require '@lutest_release'

export type TestSpec = types.TestSpec
export type TestMode = types.TestMode

const function register_spec(spec: TestSpec)
	if context.register(spec) then return end

	if not registry.is_active() then return end
	registry.register(spec)
end

const function test(name: string, fn: () -> ()): TestSpec
	const spec = {
		name = name,
		mode = 'run',
		fn = fn,
	}

	register_spec(spec)
	return spec
end

const function skip(name: string, fn: () -> ()): TestSpec
	const spec = {
		name = name,
		mode = 'skip',
		fn = fn,
	}

	register_spec(spec)
	return spec
end

const function only(name: string, fn: () -> ()): TestSpec
	const spec = {
		name = name,
		mode = 'only',
		fn = fn,
	}

	register_spec(spec)
	return spec
end

const function todo(name: string): TestSpec
	const spec = {
		name = name,
		mode = 'todo',
	}

	register_spec(spec)
	return spec
end

t.test('should prefer runtime register hook over local registry', function()
	const previous_hook = context.get_register()
	local captured = nil :: TestSpec?

	registry.clear()
	registry.begin 'module-a'
	context.set_register(function(spec: TestSpec)
		captured = spec
	end)

	const spec = test('runtime test', function() end)
	const local_tests = registry.collect 'module-a'
	context.set_register(previous_hook)
	registry.clear()

	assert(captured ~= nil)
	assert(captured == spec)
	assert(captured.name == 'runtime test')
	assert(captured.mode == 'run')
	assert(#local_tests == 0)
end)

t.test(
	'should ignore specs when no runtime hook exists and registry is inactive',
	function()
		const previous_hook = context.get_register()
		context.clear_register()
		registry.clear()

		const spec = test('inactive test', function() end)
		const tests = registry.collect 'module-a'
		context.set_register(previous_hook)
		registry.clear()

		assert(spec.name == 'inactive test')
		assert(spec.mode == 'run')
		assert(#tests == 0)
		assert(registry.is_active() == false)
	end
)

t.test(
	'should register run, skip, only, and todo specs with the expected public shape',
	function()
		const previous_hook = context.get_register()
		const run_fn = function() end
		const skip_fn = function() end
		const only_fn = function() end

		context.clear_register()
		registry.clear()
		registry.begin 'module-a'

		test('run test', run_fn)
		skip('skip test', skip_fn)
		only('only test', only_fn)
		todo 'todo test'

		const specs = registry.collect 'module-a'

		context.set_register(previous_hook)
		assert(#specs == 4)

		const run_spec = specs[1]
		const skip_spec = specs[2]
		const only_spec = specs[3]
		const todo_spec = specs[4]

		assert(run_spec.name == 'run test')
		assert(run_spec.mode == 'run')
		if run_spec.mode == 'run' then assert(run_spec.fn == run_fn) end

		assert(skip_spec.name == 'skip test')
		assert(skip_spec.mode == 'skip')
		if skip_spec.mode == 'skip' then
			assert(skip_spec.fn == skip_fn)
		end

		assert(only_spec.name == 'only test')
		assert(only_spec.mode == 'only')
		if only_spec.mode == 'only' then
			assert(only_spec.fn == only_fn)
		end

		assert(todo_spec.name == 'todo test')
		assert(todo_spec.mode == 'todo')

		registry.clear()
	end
)

t.test('should return the created spec from each public helper', function()
	const previous_hook = context.get_register()
	const run_fn = function() end
	const skip_fn = function() end
	const only_fn = function() end

	context.clear_register()
	registry.clear()

	const run_spec = test('run test', run_fn)
	const skip_spec = skip('skip test', skip_fn)
	const only_spec = only('only test', only_fn)
	const todo_spec = todo 'todo test'

	context.set_register(previous_hook)
	registry.clear()

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

const api = {
	test = test,
	skip = skip,
	only = only,
	todo = todo,
}

t.test('should keep the runtime register outside the public API', function()
	assert((api :: any).set_runtime_register == nil)
end)

return api
