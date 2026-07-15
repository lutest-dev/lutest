const embedded_assets = require '@self/embedded_assets'
const transform = require '@self/library_transform'
const t = require '@lutest_release'

const transform_source = transform.transform_source

const function files(layout: transform.LibraryLayout): { transform.LibraryFile }
	return transform.files(layout, embedded_assets.library)
end

t.test('should transform the package entry for a Roblox module tree', function()
	const source = transform_source(
		'lib/init.luau',
		[[
const types = require '@core/types'
const registry = require '@self/registry'
const context = require '@self/context'
const t = require '@lutest_release'
t.test('self test', function() end)
return registry
]],
		'package'
	)

	assert(source:find('require(script.core.types)', 1, true) ~= nil)
	assert(source:find('require(script.registry)', 1, true) ~= nil)
	assert(source:find('require(script.context)', 1, true) ~= nil)
	assert(source:find('@lutest_release', 1, true) == nil)
	assert(source:find('self test', 1, true) == nil)
end)

t.test('should transform the bundle entry for sibling modules', function()
	const source = transform_source(
		'lib/init.luau',
		[[
const registry = require '@self/registry'
return registry
]],
		'bundle'
	)

	assert(source:find('require(script.Parent.registry)', 1, true) ~= nil)
end)

t.test('should make the embedded type module requireable', function()
	assert(
		transform_source('core/types.luau', 'return nil', 'package')
			== 'return {}'
	)
end)

t.test('should prepare supplied sources as a Roblox package', function()
	const files = transform.files('package', {
		['lib/init.luau'] = 'const registry = require \'@self/registry\'\nreturn registry',
		['lib/context.luau'] = 'return {}',
		['lib/registry.luau'] = 'return {}',
		['core/types.luau'] = 'return nil',
		['core/executor.luau'] = 'const types = require \'@core/types\'\nreturn types',
	})

	assert(files[1].relative == 'init.luau')
	assert(files[1].source:find('require(script.registry)', 1, true) ~= nil)
	assert(files[5].relative == 'core/executor.luau')
	assert(
		files[5].source:find('require(script.Parent.types)', 1, true)
			~= nil
	)
end)

return {
	files = files,
}
