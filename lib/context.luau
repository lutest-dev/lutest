const types = require '@core/types'

export type TestSpec = types.TestSpec
export type RuntimeRegister = (TestSpec) -> ()

local runtime_register = nil :: RuntimeRegister?
local registration_owner = nil :: unknown?
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

const function get_registration_owner(): unknown?
	return registration_owner
end

const function set_registration_owner(owner: unknown?): unknown?
	const previous_owner = registration_owner
	registration_owner = owner
	return previous_owner
end

const function register(spec: TestSpec): boolean
	const register_fn = runtime_register
	if register_fn == nil then return false end

	register_fn(spec)
	return true
end

return {
	begin_session = begin_session,
	clear_register = clear_register,
	end_session = end_session,
	get_register = get_register,
	get_registration_owner = get_registration_owner,
	is_running = is_running,
	register = register,
	set_register = set_register,
	set_registration_owner = set_registration_owner,
}
