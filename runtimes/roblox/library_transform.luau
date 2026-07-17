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
	local stripped = ''
	local cursor = 1

	while true do
		const test_start = source:find('\nt.test', cursor, true)
		if test_start == nil then break end

		const call_start = source:find('(', test_start, true)
		assert(
			call_start ~= nil,
			'Could not parse an embedded Lutest self-test.'
		)

		local depth = 0
		local quote = nil :: string?
		local call_end = nil :: number?
		local index = call_start :: number
		while index <= #source do
			const character = source:sub(index, index)
			if quote ~= nil then
				if character == '\\' then
					index += 1
				elseif character == quote then
					quote = nil
				end
			elseif
				character == '\''
				or character == '"'
				or character == '`'
			then
				quote = character
			elseif character == '(' then
				depth += 1
			elseif character == ')' then
				depth -= 1
				if depth == 0 then
					call_end = index
					break
				end
			end
			index += 1
		end

		assert(
			call_end ~= nil,
			'Could not remove an embedded Lutest self-test.'
		)
		stripped ..= source:sub(cursor, test_start :: number)
		cursor = (call_end :: number) + 1
	end

	stripped ..= source:sub(cursor)
	return (stripped:gsub('const t = require \'@lutest_release\'\n', ''))
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
		transformed = transformed:gsub(
			'require \'@lib/context\'',
			'require(script.Parent.Parent.context)'
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
