const fs = require '@std/fs'
const json = require '@std/json'
const path = require '@std/path'
const process = require '@std/process'
const system = require '@std/system'
const errors = require '@core/errors'
const config = require '@runtimes/lute/config'
const path_utils = require '@lutest/utils/path'
const t = require '@lutest_release'

export type BundleFile = {
	absolute: string,
	relative: string,
	source: string?,
	test_suite: boolean?,
}

type SourcemapNode = {
	name: string,
	file_paths: { string },
	children: { SourcemapNode },
}

type SourceMapping = {
	absolute: string,
	relative: string,
}

const function rojo_command(): string
	const configured = process.env.LUTEST_ROJO_BIN
	if type(configured) == 'string' and configured ~= '' then
		return configured
	end
	return 'rojo'
end

const function normalize(filepath: string): string
	const without_extended_prefix = (filepath:gsub('^//%?/', ''))
	return path_utils.normalize_path(without_extended_prefix)
end

const function temporary_sourcemap_path(): string
	const nonce = `{os.time()}-{math.random(100000, 999999)}`
	return normalize(
		path.format(
			path.join(
				system.tmpdir(),
				`lutest-rojo-sourcemap-{nonce}.json`
			)
		)
	)
end

const function configuration_error(project_path: string, details: string): never
	error(
		errors.configuration_error(
			'Could not create a Rojo source map.',
			{
				where = project_path,
				how_to_fix = 'Install Rojo and ensure the configured project file is valid, or remove roblox.rojo_project.',
				details = details,
			}
		),
		0
	)
end

const function string_array(value: json.Value?): { string }
	const array = if value == nil then nil else json.asArray(value)
	if array == nil then return {} end

	const result = {} :: { string }
	for _, entry in array do
		if typeof(entry) == 'string' then
			table.insert(result, entry)
		end
	end
	return result
end

const function sourcemap_node(value: json.Value): SourcemapNode?
	const object = json.asObject(value)
	if object == nil or typeof(object.name) ~= 'string' then return nil end

	const children = {} :: { SourcemapNode }
	const child_values = json.asArray(object.children)
	if child_values ~= nil then
		for _, child in child_values do
			const parsed = sourcemap_node(child)
			if parsed ~= nil then table.insert(children, parsed) end
		end
	end

	return {
		name = object.name,
		file_paths = string_array(object.filePaths),
		children = children,
	}
end

const function map_node(
	node: SourcemapNode,
	segments: { string },
	known_paths: { [string]: BundleFile },
	mapped_paths: { [string]: string },
	source_mappings: { SourceMapping }
)
	for _, file_path in node.file_paths do
		const absolute = normalize(file_path)
		const relative = table.concat(segments, '/')
		table.insert(source_mappings, {
			absolute = absolute,
			relative = relative,
		})

		const file = known_paths[absolute]
		if file ~= nil then mapped_paths[file.absolute] = relative end
	end

	for _, child in node.children do
		const child_segments = table.clone(segments)
		table.insert(child_segments, child.name)
		map_node(
			child,
			child_segments,
			known_paths,
			mapped_paths,
			source_mappings
		)
	end
end

const function map_linked_files(
	files: { BundleFile },
	mapped_paths: { [string]: string },
	source_mappings: { SourceMapping }
)
	for _, file in files do
		if mapped_paths[file.absolute] ~= nil then continue end
		const parent = path.dirname(file.absolute)
		const basename = path.basename(file.absolute)
		local linked = false
		if basename ~= nil then
			for _, entry in fs.listDirectory(parent) do
				if
					entry.name == basename
					and entry.type == 'link'
				then
					linked = true
					break
				end
			end
		end
		if not linked then continue end

		const contents = fs.readFileToString(file.absolute)
		local matching_path = nil :: string?
		for _, source in source_mappings do
			local source_contents = nil :: string?
			const readable = pcall(function()
				source_contents =
					fs.readFileToString(source.absolute)
			end)
			if not readable or source_contents ~= contents then
				continue
			end
			if matching_path ~= nil then
				matching_path = nil
				break
			end
			matching_path = source.relative
		end
		if matching_path ~= nil then
			mapped_paths[file.absolute] = matching_path
		end
	end
end

const function append_rojo_sources(
	files: { BundleFile },
	source_mappings: { SourceMapping }
)
	const mapped_relatives = {} :: { [string]: boolean }
	for _, file in files do
		mapped_relatives[file.relative] = true
	end

	for _, source in source_mappings do
		if
			not source.absolute:match '%.luau$'
			and not source.absolute:match '%.lua$'
		then
			continue
		end
		if not fs.exists(source.absolute) then continue end
		if mapped_relatives[source.relative] then continue end

		mapped_relatives[source.relative] = true
		table.insert(files, {
			absolute = source.absolute,
			relative = source.relative,
		})
	end
end

const function map_files(
	files: { BundleFile },
	configured_project_path: string?,
	config_path: string?
): { BundleFile }
	if configured_project_path == nil or configured_project_path == '' then
		return files
	end
	const resolved_config_path = config.resolve_config_path(config_path)
	const project_path = path_utils.resolve_path(
		path.dirname(resolved_config_path),
		configured_project_path
	)
	const output_path = temporary_sourcemap_path()
	local result = nil :: process.ProcessResult?
	local run_error = nil :: string?
	const ran = xpcall(function()
		result = process.run {
			rojo_command(),
			'sourcemap',
			'--absolute',
			'--output',
			output_path,
			project_path,
		}
	end, function(err)
		run_error = tostring(err)
		return run_error
	end)
	if
		not ran
		or result == nil
		or (result :: process.ProcessResult).exitcode ~= 0
	then
		configuration_error(
			project_path,
			run_error or (result :: process.ProcessResult).stderr
		)
	end
	if not fs.exists(output_path) then
		configuration_error(
			project_path,
			'Rojo completed without writing a source map.'
		)
	end

	local decoded = nil :: json.Value?
	local decode_error = nil :: string?
	const decoded_ok = xpcall(function()
		decoded = json.deserialize(fs.readFileToString(output_path))
	end, function(err)
		decode_error = tostring(err)
		return decode_error
	end)
	fs.remove(output_path)
	if not decoded_ok or decoded == nil then
		configuration_error(project_path, decode_error :: string)
	end

	const root = sourcemap_node(decoded :: json.Value)
	if root == nil then
		configuration_error(
			project_path,
			'Rojo produced an invalid source map.'
		)
	end

	const known_paths = {} :: { [string]: BundleFile }
	for _, file in files do
		known_paths[normalize(file.absolute)] = file
	end
	const mapped_paths = {} :: { [string]: string }
	const source_mappings = {} :: { SourceMapping }
	map_node(
		root :: SourcemapNode,
		{},
		known_paths,
		mapped_paths,
		source_mappings
	)
	map_linked_files(files, mapped_paths, source_mappings)

	const mapped = {} :: { BundleFile }
	for _, file in files do
		table.insert(mapped, {
			absolute = file.absolute,
			relative = mapped_paths[file.absolute] or file.relative,
			source = file.source,
			test_suite = file.test_suite,
		})
	end
	append_rojo_sources(mapped, source_mappings)
	return mapped
end

t.test('should map source files below their Rojo instance paths', function()
	const source = 'C:/project/src/ok.luau'
	const file = {
		absolute = source,
		relative = 'src/ok.luau',
	} :: BundleFile
	const mapped = {} :: { [string]: string }
	map_node({
		name = 'Game',
		file_paths = {},
		children = {
			{
				name = 'ReplicatedStorage',
				file_paths = {},
				children = {
					{
						name = 'ok',
						file_paths = { source },
						children = {},
					},
				},
			},
		},
	}, {}, { [normalize(source)] = file }, mapped, {})
	assert(mapped[source] == 'ReplicatedStorage/ok')
end)

t.test('should normalize Windows extended-length source map paths', function()
	assert(
		normalize '//?/C:/project/src/ok.luau'
			== 'C:/project/src/ok.luau'
	)
end)

t.test('should map a file symbolic link to its Rojo source path', function()
	const temp_root = path_utils.resolve_path(
		path_utils.cwd(),
		'dist/test-tmp/rojo-file-link'
	)
	const source_path = path_utils.resolve_path(temp_root, 'src/ok.luau')
	const link_path = path_utils.resolve_path(temp_root, 'tests/ok.luau')

	if fs.exists(temp_root) then
		fs.removeDirectory(temp_root, { recursive = true })
	end
	fs.createDirectory(path.dirname(source_path), { makeParents = true })
	fs.createDirectory(path.dirname(link_path), { makeParents = true })
	fs.writeStringToFile(source_path, 'return {}')
	const linked = pcall(function()
		fs.symbolicLink(source_path, link_path)
	end)
	if not linked then
		fs.removeDirectory(temp_root, { recursive = true })
		return
	end

	const mapped = {} :: { [string]: string }
	map_linked_files(
		{
			{
				absolute = link_path,
				relative = 'tests/ok.luau',
			},
		},
		mapped,
		{
			{
				absolute = source_path,
				relative = 'ReplicatedStorage/ok',
			},
		}
	)
	assert(mapped[link_path] == 'ReplicatedStorage/ok')

	fs.removeDirectory(temp_root, { recursive = true })
end)

t.test('should include Rojo sources outside discovery roots', function()
	const temp_root = path_utils.resolve_path(
		path_utils.cwd(),
		'dist/test-tmp/rojo-extra-source'
	)
	const dependency_path = path_utils.resolve_path(
		temp_root,
		'roblox_packages/dependency.lua'
	)

	if fs.exists(temp_root) then
		fs.removeDirectory(temp_root, { recursive = true })
	end
	fs.createDirectory(path.dirname(dependency_path), {
		makeParents = true,
	})
	fs.writeStringToFile(dependency_path, 'return {}')

	const files = {
		{
			absolute = 'example/wallet.luau',
			relative = 'ServerScriptService/wallet',
		},
	} :: { BundleFile }
	append_rojo_sources(files, {
		{
			absolute = dependency_path,
			relative = 'ReplicatedStorage/Packages/dependency',
		},
	})
	assert(#files == 2)
	assert(files[2].relative == 'ReplicatedStorage/Packages/dependency')

	fs.removeDirectory(temp_root, { recursive = true })
end)

t.test('should preserve paths when Rojo mapping is not configured', function()
	const files = {
		{
			absolute = 'src/ok.luau',
			relative = 'src/ok.luau',
		},
	} :: { BundleFile }
	assert(map_files(files, nil, nil) == files)
end)

return {
	map_files = map_files,
}
