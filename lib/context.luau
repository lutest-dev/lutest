const types = require '@core/types'
const t = require '@lutest_release'

export type TestSpec = types.TestSpec
export type RuntimeRegister = (TestSpec) -> ()

local runtime_register = nil :: RuntimeRegister?
local session_depth = 0

const function begin_session()
	session_depth += 1
end

const function end_session()
	assert(session_depth > 0, 'Cannot end an inactive Lutest session.')
	session_depth -= 1
end

const function is_running(): boolean
	return session_depth > 0
end

const function get_register(): RuntimeRegister?
	return runtime_register
end

const function set_register(register_fn: RuntimeRegister?)
	runtime_register = register_fn
end

const function clear_register()
	runtime_register = nil
end

const function register(spec: TestSpec): boolean
	const register_fn = runtime_register
	if register_fn == nil then return false end

	register_fn(spec)
	return true
end

t.test('should start without an active runtime register', function()
	clear_register()

	assert(get_register() == nil)
	assert(register {
		name = 'orphan test',
		mode = 'run',
		fn = function() end,
	} == false)
end)

t.test('should expose the active runtime register', function()
	clear_register()

	local captured = nil :: TestSpec?
	const register_fn = function(spec: TestSpec)
		captured = spec
	end

	set_register(register_fn)

	const active_register = get_register()
	assert(active_register ~= nil)
	assert(active_register == register_fn)

	active_register {
		name = 'runtime test',
		mode = 'run',
		fn = function() end,
	}

	assert(captured ~= nil)
	assert(captured.name == 'runtime test')

	clear_register()
end)

t.test('should forward specs to the active runtime register', function()
	clear_register()

	local captured = nil :: TestSpec?
	set_register(function(spec: TestSpec)
		captured = spec
	end)

	const spec = {
		name = 'forwarded test',
		mode = 'only',
		fn = function() end,
	} :: TestSpec

	assert(register(spec) == true)
	assert(captured == spec)

	clear_register()
end)

t.test('should clear the active runtime register', function()
	clear_register()
	set_register(function(_: TestSpec) end)

	clear_register()

	assert(get_register() == nil)
	assert(register {
		name = 'cleared test',
		mode = 'run',
		fn = function() end,
	} == false)
end)

t.test('should track active Lutest sessions', function()
	assert(is_running() == false)
	begin_session()
	assert(is_running() == true)
	begin_session()
	end_session()
	assert(is_running() == true)
	end_session()
	assert(is_running() == false)
end)

return {
	begin_session = begin_session,
	clear_register = clear_register,
	end_session = end_session,
	get_register = get_register,
	is_running = is_running,
	register = register,
	set_register = set_register,
}
