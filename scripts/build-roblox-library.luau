const fs = require '@std/fs'
const json = require '@std/json'
const path = require '@std/path'
const process = require '@std/process'
const transform = require '@runtimes/roblox/library_transform'

const DEFAULT_PACKAGE_ROOT = '.tmp/wally-package'
const DEFAULT_OUTPUT = 'dist/Lib.rbxm'
const MANIFEST_PATH = '.tmp/roblox-library-manifest.json'

const function ensure_directory(directory: string)
	if directory == '' or directory == '.' or fs.exists(directory) then
		return
	end
	fs.createDirectory(directory, { makeParents = true })
end

const function resolve_path(cwd: string, value: string): string
	if path.isAbsolute(value) then
		return path.format(path.normalize(value))
	end
	return path.format(path.normalize(path.join(cwd, value)))
end

const function manifest(package_root: string): string
	const files = {} :: json.Array
	for _, relative_path in transform.package_paths() do
		const absolute_path = path.format(
			path.normalize(path.join(package_root, relative_path))
		)
		assert(
			fs.exists(absolute_path),
			`Missing packaged Lutest library source '{relative_path}'.`
		)
		table.insert(
			files,
			json.object {
				absolute = absolute_path,
				relative = relative_path,
			}
		)
	end
	return json.serialize(json.object { files = files })
end

const function build(package_root: string, output_path: string)
	ensure_directory(path.format(path.dirname(output_path)))
	ensure_directory(path.format(path.dirname(MANIFEST_PATH)))
	fs.writeStringToFile(MANIFEST_PATH, manifest(package_root))

	const result = process.run({
		'lune',
		'run',
		'scripts/build-roblox-bundle.luau',
		'--manifest',
		MANIFEST_PATH,
		'--output',
		output_path,
		'--root-name',
		'Lib',
		'--root-module',
		'init.luau',
	}, { stdio = 'inherit' })
	fs.remove(MANIFEST_PATH)
	assert(
		result.exitcode == 0,
		'Could not build the Lutest Roblox library.'
	)
	assert(
		fs.exists(output_path),
		'Lune did not produce the Lutest Roblox library.'
	)
	print(`Roblox library prepared: {output_path}`)
end

const cwd = path.format(path.normalize(process.cwd()))
const package_root = resolve_path(cwd, process.args[2] or DEFAULT_PACKAGE_ROOT)
const output_path = resolve_path(cwd, process.args[3] or DEFAULT_OUTPUT)
build(package_root, output_path)
