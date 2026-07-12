const embedded_assets = require '@self/embedded_assets'
const t = require '@lutest_release'

export type LibraryLayout = 'package' | 'bundle'

export type LibraryFile = {
	relative: string,
	source: string,
}

const SOURCE_FILES = {
	'lib/init.luau',
	'lib/context.luau',
	'lib/registry.luau',
	'core/types.luau',
}

const function strip_self_tests(source: string): string
	const test_start = source:find('\nt.test', 1, true)
	if test_start == nil then return source end

	const return_start = source:find('\nreturn ', test_start, true)
	assert(
		return_start ~= nil,
		'Could not remove embedded Lutest self-tests.'
	)

	local stripped = source:sub(1, (test_start :: number) - 1)
		.. source:sub(return_start :: number)
	stripped = stripped:gsub('const t = require \'@lutest_release\'\n', '')
	return stripped
end

const function transform_source(
	source_path: string,
	source: string,
	layout: LibraryLayout
): string
	local transformed = strip_self_tests(source)

	if source_path == 'lib/init.luau' then
		const root = if layout == 'package'
			then 'script'
			else 'script.Parent'
		transformed = transformed:gsub(
			'require \'@core/types\'',
			`require({root}.core.types)`
		)
		transformed = transformed:gsub(
			'require \'@self/registry\'',
			`require({root}.registry)`
		)
		transformed = transformed:gsub(
			'require \'@self/context\'',
			`require({root}.context)`
		)
	else
		transformed = transformed:gsub(
			'require \'@core/types\'',
			'require(script.Parent.core.types)'
		)
	end

	if source_path == 'core/types.luau' then
		transformed = transformed:gsub('^return nil', 'return {}')
		transformed = transformed:gsub('\nreturn nil', '\nreturn {}')
	end

	return transformed
end

const function output_path(source_path: string, layout: LibraryLayout): string
	if source_path ~= 'lib/init.luau' then
		return (source_path:gsub('^lib/', ''))
	end

	return if layout == 'package' then 'init.luau' else 'lib.luau'
end

const function files(layout: LibraryLayout): { LibraryFile }
	const files = {} :: { LibraryFile }
	for _, source_path in SOURCE_FILES do
		const source = embedded_assets.library[source_path]
		assert(
			type(source) == 'string',
			`Missing embedded Lutest library source '{source_path}'.`
		)
		table.insert(files, {
			relative = output_path(source_path, layout),
			source = transform_source(source_path, source, layout),
		})
	end
	return files
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

return {
	files = files,
}
