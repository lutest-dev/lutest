const types = require '@core/types'

export type TestSpec = types.TestSpec

type TestsByModule = { [string]: { TestSpec } }

const tests_by_module = {} :: TestsByModule
local active = false

const function begin()
	active = true

	for module_identity in tests_by_module do
		tests_by_module[module_identity] = nil
	end
end

const function register(module_identity: string, test: TestSpec)
	if not active then return end

	if tests_by_module[module_identity] == nil then
		tests_by_module[module_identity] = {}
	end

	table.insert(tests_by_module[module_identity], test)
end

const function collect(module_identity: string): { TestSpec }
	const tests = tests_by_module[module_identity]
	if tests == nil then return {} end

	return tests
end

const function clear()
	active = false

	for module_identity in tests_by_module do
		tests_by_module[module_identity] = nil
	end
end

const function is_active(): boolean
	return active
end

return {
	begin = begin,
	clear = clear,
	collect = collect,
	is_active = is_active,
	register = register,
}
