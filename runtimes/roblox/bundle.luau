const fs = require '@std/fs'
const json = require '@std/json'
const path = require '@std/path'
const process = require '@std/process'
const errors = require '@core/errors'
const path_utils = require '@lutest/utils/path'
const embedded_assets = require '@self/embedded_assets'
const t = require '@lutest_release'

export type BundleFile = {
	absolute: string,
	relative: string,
	source: string?,
	test_suite: boolean?,
}

type BundlePaths = {
	manifest: string,
	output: string,
	script: string,
}

const BUNDLE_DIRECTORY = 'dist/.lutest/roblox'
const LIBRARY_FILES = {
	{ source = 'lib/init.luau', relative = '__lutest_lib/lib.luau' },
	{ source = 'lib/context.luau', relative = '__lutest_lib/context.luau' },
	{
		source = 'lib/registry.luau',
		relative = '__lutest_lib/registry.luau',
	},
	{
		source = 'core/types.luau',
		relative = '__lutest_lib/core/types.luau',
	},
}

const function lune_command(): string
	const configured = process.env.LUTEST_LUNE_BIN
	if type(configured) == 'string' and configured ~= '' then
		return configured
	end
	return 'lune'
end

const function runtime_error(summary: string, details: string?): never
	error(
		errors.runtime_error(summary, {
			where = 'Roblox bundle preparation',
			how_to_fix = 'Install Lune on PATH, or set LUTEST_LUNE_BIN to its executable path.',
			details = details,
		}),
		0
	)
end

const function ensure_lune_available(command: string)
	local result = nil :: process.ProcessResult?
	local failure = nil :: string?
	const ok = xpcall(function()
		result = process.run { command, '--version' }
	end, function(err)
		failure = tostring(err)
		return failure
	end)
	if
		not ok
		or result == nil
		or (result :: process.ProcessResult).exitcode ~= 0
	then
		runtime_error(
			`Could not run Lune executable '{command}'.`,
			failure
		)
	end
end

const function bundle_paths(): BundlePaths
	const directory =
		path_utils.resolve_path(path_utils.cwd(), BUNDLE_DIRECTORY)
	path_utils.ensure_directory(directory)
	const nonce = `{os.time()}-{math.random(100000, 999999)}`
	return {
		manifest = path_utils.normalize_path(
			path.join(directory, `bundle-{nonce}.json`)
		),
		output = path_utils.normalize_path(
			path.join(directory, `bundle-{nonce}.rbxm`)
		),
		script = path_utils.normalize_path(
			path.join(directory, `bundle-{nonce}.luau`)
		),
	}
end

const function manifest(files: { BundleFile }): string
	const encoded = {} :: json.Array
	for _, file in files do
		const entry = json.object {
			absolute = file.absolute,
			relative = file.relative,
		}
		if file.source ~= nil then entry.source = file.source end
		if file.test_suite ~= nil then
			entry.test_suite = file.test_suite
		end
		table.insert(encoded, entry)
	end
	return json.serialize(json.object {
		files = encoded,
	})
end

const function strip_library_self_tests(source: string): string
	const test_start = source:find('\nt.test', 1, true)
	if test_start == nil then return source end
	const return_start = source:find('\nreturn ', test_start, true)
	if return_start == nil then
		runtime_error 'Could not remove embedded Lutest self-tests from the Roblox bundle.'
	end

	local stripped = source:sub(1, (test_start :: number) - 1)
		.. source:sub(return_start :: number)
	stripped = stripped:gsub('const t = require \'@lutest_release\'\n', '')
	return stripped
end

const function transform_library_imports(source: string): string
	local transformed = strip_library_self_tests(source)
	transformed = transformed:gsub(
		'require \'@self/registry\'',
		'require(script.Parent.registry)'
	)
	transformed = transformed:gsub(
		'require \'@self/context\'',
		'require(script.Parent.context)'
	)
	transformed = transformed:gsub(
		'require \'@core/types\'',
		'require(script.Parent.core.types)'
	)
	return transformed
end

const function transform_library_source(
	relative_path: string,
	source: string
): string
	const transformed = transform_library_imports(source)
	if relative_path ~= '__lutest_lib/core/types.luau' then
		return transformed
	end
	local requireable = transformed:gsub('^return nil', 'return {}')
	requireable = requireable:gsub('\nreturn nil', '\nreturn {}')
	return requireable
end

const function bundled_library_files(): { BundleFile }
	const files = {} :: { BundleFile }
	for _, entry in LIBRARY_FILES do
		const source = embedded_assets.library[entry.source]
		if type(source) ~= 'string' then
			runtime_error(
				`Missing embedded Lutest library source '{entry.source}'.`
			)
		end

		const file: BundleFile = {
			absolute = entry.source,
			relative = entry.relative,
			source = transform_library_source(
				entry.relative,
				source
			),
		}
		table.insert(files, file)
	end
	return files
end

const function is_test_suite(file: BundleFile, suite_paths: { string }): boolean
	for _, suite_path in suite_paths do
		if file.relative == suite_path then return true end
	end
	return false
end

const function all_bundle_files(
	files: { BundleFile },
	suite_paths: { string }
): { BundleFile }
	const bundled = bundled_library_files()
	for _, file in files do
		table.insert(bundled, {
			absolute = file.absolute,
			relative = file.relative,
			source = file.source,
			test_suite = is_test_suite(file, suite_paths) or nil,
		})
	end
	return bundled
end

const function remove_temporary_files(paths: BundlePaths)
	fs.remove(paths.manifest)
	fs.remove(paths.script)
end

const function run_lune(
	command: string,
	paths: BundlePaths
): (process.ProcessResult?, string?, boolean)
	local result = nil :: process.ProcessResult?
	local run_error = nil :: string?
	const ok = xpcall(function()
		result = process.run {
			command,
			'run',
			paths.script,
			'--manifest',
			paths.manifest,
			'--output',
			paths.output,
		}
	end, function(err)
		run_error = tostring(err)
		return run_error
	end)
	return result, run_error, ok
end

const function build(files: { BundleFile }, suite_paths: { string }): string
	if #files == 0 then
		runtime_error 'Could not prepare an empty Roblox test bundle.'
	end

	const command = lune_command()
	ensure_lune_available(command)
	const paths = bundle_paths()
	fs.writeStringToFile(
		paths.manifest,
		manifest(all_bundle_files(files, suite_paths))
	)
	if embedded_assets.bundle_script == '' then
		runtime_error 'Missing embedded Roblox bundle script.'
	end
	fs.writeStringToFile(paths.script, embedded_assets.bundle_script)

	const result, run_error, ok = run_lune(command, paths)
	remove_temporary_files(paths)
	if
		not ok
		or result == nil
		or (result :: process.ProcessResult).exitcode ~= 0
	then
		runtime_error(
			'Lune could not create the Roblox RBXM bundle.',
			run_error or (result :: process.ProcessResult).stderr
		)
	end
	if not fs.exists(paths.output) then
		runtime_error 'Lune completed without producing a Roblox RBXM bundle.'
	end

	const binary = fs.readFileToString(paths.output)
	fs.remove(paths.output)
	return binary
end

t.test('should encode source files as a Lune bundle manifest', function()
	const output = manifest {
		{
			absolute = 'C:/project/src/example.luau',
			relative = 'src/example.luau',
		},
	}
	assert(output:find('src/example.luau', 1, true) ~= nil)
end)

t.test('should make the embedded type module requireable in Roblox', function()
	assert(
		transform_library_source(
			'__lutest_lib/core/types.luau',
			'return nil'
		) == 'return {}'
	)
end)

t.test('should transform internal library imports for Roblox', function()
	const source = transform_library_imports [[
const types = require '@core/types'
const registry = require '@self/registry'
const t = require '@lutest_release'
t.test('self test', function() end)
return registry
]]
	assert(source:find('require(script.Parent.core.types)', 1, true) ~= nil)
	assert(source:find('require(script.Parent.registry)', 1, true) ~= nil)
	assert(source:find('@lutest_release', 1, true) == nil)
	assert(source:find('self test', 1, true) == nil)
end)

return {
	build = build,
}
