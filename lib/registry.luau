const types = require '@core/types'

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

return {
	begin = begin,
	clear = clear,
	collect = collect,
	is_active = is_active,
	register = register,
}
