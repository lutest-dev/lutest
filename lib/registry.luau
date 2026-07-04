const types = require '@core/types'
const t = require '@lutest_release'

export type TestSpec = types.TestSpec
export type TestMode = types.TestMode

type TestBuckets = { [string]: { TestSpec } }

const test_buckets = {} :: TestBuckets
local active_module_identity = nil :: string?

const function bucket_for(module_identity: string): { TestSpec }
	local bucket = test_buckets[module_identity]
	if bucket ~= nil then return bucket end

	bucket = {}
	test_buckets[module_identity] = bucket
	return bucket
end

const function clear_bucket(bucket: { TestSpec })
	while #bucket > 0 do
		table.remove(bucket)
	end
end

const function begin(module_identity: string)
	active_module_identity = module_identity
	clear_bucket(bucket_for(module_identity))
end

const function register(test: TestSpec)
	const module_identity = active_module_identity
	if module_identity == nil then return end

	table.insert(bucket_for(module_identity), test)
end

const function collect(module_identity: string): { TestSpec }
	return bucket_for(module_identity)
end

const function clear(module_identity: string?)
	if module_identity == nil then
		active_module_identity = nil

		for _, bucket in test_buckets do
			clear_bucket(bucket)
		end

		return
	end

	clear_bucket(bucket_for(module_identity))
	if active_module_identity == module_identity then
		active_module_identity = nil
	end
end

const function is_active(): boolean
	return active_module_identity ~= nil
end

t.test('should reset bucket on repeated begin', function()
	clear()

	begin 'module-a'
	register {
		name = 'first test',
		mode = 'run',
		fn = function() end,
	}

	begin 'module-a'
	register {
		name = 'second test',
		mode = 'run',
		fn = function() end,
	}

	const tests = collect 'module-a'

	assert(#tests == 1)
	assert(tests[1].name == 'second test')

	clear()
end)

t.test('should keep active module when clearing another bucket', function()
	clear()

	begin 'module-a'
	register {
		name = 'test a',
		mode = 'run',
		fn = function() end,
	}

	begin 'module-b'
	register {
		name = 'test b',
		mode = 'run',
		fn = function() end,
	}

	clear 'module-a'
	register {
		name = 'test b2',
		mode = 'run',
		fn = function() end,
	}

	const module_a_tests = collect 'module-a'
	const module_b_tests = collect 'module-b'

	assert(is_active() == true)
	assert(#module_a_tests == 0)
	assert(#module_b_tests == 2)
	assert(module_b_tests[1].name == 'test b')
	assert(module_b_tests[2].name == 'test b2')

	clear()
end)

t.test('should ignore register without active module', function()
	clear()
	register {
		name = 'orphan test',
		mode = 'run',
		fn = function() end,
	}

	const tests = collect 'module-a'

	assert(is_active() == false)
	assert(#tests == 0)
end)

t.test('should collect tests by module', function()
	clear()

	begin 'module-a'
	register {
		name = 'test a',
		mode = 'run',
		fn = function() end,
	}

	begin 'module-b'
	register {
		name = 'test b',
		mode = 'run',
		fn = function() end,
	}

	const module_a_tests = collect 'module-a'
	const module_b_tests = collect 'module-b'

	assert(#module_a_tests == 1)
	assert(module_a_tests[1].name == 'test a')
	assert(#module_b_tests == 1)
	assert(module_b_tests[1].name == 'test b')

	clear()
end)

t.test('should clear only one module bucket', function()
	clear()

	begin 'module-a'
	register {
		name = 'test a',
		mode = 'run',
		fn = function() end,
	}

	begin 'module-b'
	register {
		name = 'test b',
		mode = 'run',
		fn = function() end,
	}

	clear 'module-a'

	const module_a_tests = collect 'module-a'
	const module_b_tests = collect 'module-b'

	assert(#module_a_tests == 0)
	assert(#module_b_tests == 1)
	assert(module_b_tests[1].name == 'test b')

	clear()
end)

t.test('should clear all buckets on global clear', function()
	clear()

	begin 'module-a'
	register {
		name = 'test a',
		mode = 'run',
		fn = function() end,
	}

	begin 'module-b'
	register {
		name = 'test b',
		mode = 'run',
		fn = function() end,
	}

	clear()

	const module_a_tests = collect 'module-a'
	const module_b_tests = collect 'module-b'

	assert(is_active() == false)
	assert(#module_a_tests == 0)
	assert(#module_b_tests == 0)
end)

t.test('should deactivate on active module clear', function()
	clear()

	begin 'module-a'
	register {
		name = 'test a',
		mode = 'run',
		fn = function() end,
	}

	begin 'module-b'
	register {
		name = 'test b',
		mode = 'run',
		fn = function() end,
	}

	clear 'module-b'

	const module_a_tests = collect 'module-a'
	const module_b_tests = collect 'module-b'

	assert(is_active() == false)
	assert(#module_a_tests == 1)
	assert(module_a_tests[1].name == 'test a')
	assert(#module_b_tests == 0)
end)

return {
	begin = begin,
	clear = clear,
	collect = collect,
	is_active = is_active,
	register = register,
}
