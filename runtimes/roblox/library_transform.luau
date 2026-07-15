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
	'core/executor.luau',
}

const function source_paths(): { string }
	return SOURCE_FILES
end

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
	elseif source_path == 'core/executor.luau' then
		transformed = transformed:gsub(
			'require \'@core/types\'',
			'require(script.Parent.types)'
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

const function files(
	layout: LibraryLayout,
	sources: { [string]: string }
): { LibraryFile }
	const output = {} :: { LibraryFile }
	for _, source_path in SOURCE_FILES do
		const source = sources[source_path]
		assert(
			type(source) == 'string',
			`Missing Lutest library source '{source_path}'.`
		)
		table.insert(output, {
			relative = output_path(source_path, layout),
			source = transform_source(source_path, source, layout),
		})
	end
	return output
end

return {
	files = files,
	source_paths = source_paths,
	transform_source = transform_source,
}
