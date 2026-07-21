const fs = require '@std/fs'
const json = require '@std/json'
const path = require '@std/path'
const process = require '@std/process'
const system = require '@std/system'
const errors = require '@core/errors'
const path_utils = require '@lutest/utils/path'
const embedded_assets = require '@self/embedded_assets'
const library = require '@self/library'
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

const BUNDLE_DIRECTORY = 'lutest/roblox'
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
			how_to_fix = 'Install Lune on PATH, or set LUTEST_LUNE_BIN '
				.. 'to its executable path.',
			details = details,
		}),
		0
	)
end

const function inspect_lune(command: string): (boolean, string?)
	local result = nil :: process.ProcessResult?
	local failure = nil :: string?
	const ok = xpcall(function()
		result = process.run { command, '--version' }
	end, function(err)
		failure = tostring(err)
		return failure
	end)
	if not ok or result == nil then return false, failure end
	if (result :: process.ProcessResult).exitcode ~= 0 then
		return false, (result :: process.ProcessResult).stderr
	end

	return true, nil
end

const function ensure_lune_available(command: string)
	const available, details = inspect_lune(command)
	if not available then
		runtime_error(
			`Could not run Lune executable '{command}'.`,
			details
		)
	end
end

const function is_available(): boolean
	const available = inspect_lune(lune_command())
	return available
end

const function bundle_directory(): string
	return path_utils.normalize_path(
		path.join(system.tmpdir(), BUNDLE_DIRECTORY)
	)
end

const function bundle_paths(): BundlePaths
	const directory = bundle_directory()
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

const function package_bundle_path(relative_path: string): string
	if relative_path == 'init.luau' then
		return `__lutest_lib/{relative_path}`
	end
	return `__lutest_lib/init/{relative_path}`
end

const function bundled_library_files(library_root: string?): { BundleFile }
	if library_root ~= nil then
		const files = {} :: { BundleFile }
		for _, relative_path in library.package_paths() do
			const absolute = path_utils.normalize_path(
				path.join(library_root, relative_path)
			)
			if not fs.exists(absolute) then
				runtime_error(
					'Missing file from supplied Roblox library package.',
					`Expected '{relative_path}' under '{library_root}'.`
				)
			end
			table.insert(files, {
				absolute = absolute,
				relative = package_bundle_path(relative_path),
			})
		end
		return files
	end

	const files = {} :: { BundleFile }
	for _, entry in library.files() do
		const file: BundleFile = {
			absolute = entry.relative,
			relative = `__lutest_lib/{entry.relative}`,
			source = entry.source,
		}
		table.insert(files, file)
	end
	return files
end

const function is_test_suite(file: BundleFile, suite_paths: { string }): boolean
	for _, suite_path in suite_paths do
		if file.absolute == suite_path then return true end
	end
	return false
end

const function all_bundle_files(
	files: { BundleFile },
	suite_paths: { string },
	library_root: string?
): { BundleFile }
	const bundled = bundled_library_files(library_root)
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

const function planned_files(
	files: { BundleFile },
	suite_paths: { string },
	library_root: string?
): { BundleFile }
	return all_bundle_files(files, suite_paths, library_root)
end

const function test_suite_paths(
	files: { BundleFile },
	suite_paths: { string }
): { string }
	const paths = {} :: { string }
	for _, file in files do
		if is_test_suite(file, suite_paths) then
			table.insert(paths, file.relative)
		end
	end
	return paths
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

const function build(
	files: { BundleFile },
	suite_paths: { string },
	library_root: string?
): string
	if #files == 0 then
		runtime_error 'Could not prepare an empty Roblox test bundle.'
	end

	const command = lune_command()
	ensure_lune_available(command)
	const paths = bundle_paths()
	fs.writeStringToFile(
		paths.manifest,
		manifest(planned_files(files, suite_paths, library_root))
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

t.test('should use mapped suite paths in the remote harness', function()
	const paths = test_suite_paths({
		{
			absolute = 'tests/ok.luau',
			relative = 'ReplicatedStorage/tests/ok',
		},
	}, { 'tests/ok.luau' })
	assert(paths[1] == 'ReplicatedStorage/tests/ok')
end)

t.test('should nest package modules under the Wally entrypoint', function()
	assert(package_bundle_path 'init.luau' == '__lutest_lib/init.luau')
	assert(
		package_bundle_path 'context.luau'
			== '__lutest_lib/init/context.luau'
	)
	assert(
		package_bundle_path 'core/executor.luau'
			== '__lutest_lib/init/core/executor.luau'
	)
end)

t.test(
	'should create Roblox bundles under the system temporary directory',
	function()
		const directory = bundle_directory()
		const temporary_root =
			path_utils.normalize_path(system.tmpdir())

		assert(directory:sub(1, #temporary_root) == temporary_root)
		assert(directory:find('/dist/', 1, true) == nil)
	end
)

return {
	build = build,
	is_available = is_available,
	planned_files = planned_files,
	test_suite_paths = test_suite_paths,
}
