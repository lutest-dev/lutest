const types = require '@core/types'
const registry = require '@self/registry'

export type TestSpec = types.TestSpec

const function normalize_module_identity(value: string): string
	const normalized = value:gsub('\\', '/')
	if normalized:sub(1, 1) == '@' then return normalized:sub(2) end

	return normalized
end

const function get_caller_module_identity(): string?
	if not registry.is_active() then return nil end

	const source = debug.info(2, 's')
	if typeof(source) ~= 'string' then return nil end
	if source == '' then return nil end

	return normalize_module_identity(source)
end

const function test(name: string, fn: () -> ()): TestSpec
	const spec = {
		name = name,
		fn = fn,
	}

	const module_identity = get_caller_module_identity()
	if module_identity == nil then return spec end

	registry.register(module_identity, spec)
	return spec
end

return {
	test = test,
}
