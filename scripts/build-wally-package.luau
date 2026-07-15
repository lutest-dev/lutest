const fs = require '@std/fs'
const path = require '@std/path'
const transform = require '@runtimes/roblox/library_transform'

const OUTPUT_ROOT = '.tmp/wally-package'

const function ensure_directory(directory: string)
	if fs.exists(directory) then return end
	fs.createDirectory(directory, { makeParents = true })
end

const function source_files(): { [string]: string }
	const sources = {} :: { [string]: string }
	for _, relative_path in transform.source_paths() do
		sources[relative_path] = fs.readFileToString(relative_path)
	end
	return sources
end

const function write_package_sources()
	for _, file in transform.files('package', source_files()) do
		const destination = path.join(OUTPUT_ROOT, 'src', file.relative)
		ensure_directory(path.dirname(destination))
		fs.writeStringToFile(destination, file.source)
	end
end

const function write_publish_manifest()
	const source = fs.readFileToString 'wally.toml'
	const manifest, replacements =
		source:gsub('private = true', 'private = false')
	assert(
		replacements == 1,
		'Expected exactly one private Wally manifest flag.'
	)
	fs.writeStringToFile(path.join(OUTPUT_ROOT, 'wally.toml'), manifest)
end

const function build()
	if fs.exists(OUTPUT_ROOT) then
		fs.removeDirectory(OUTPUT_ROOT, { recursive = true })
	end

	ensure_directory(OUTPUT_ROOT)
	write_package_sources()
	write_publish_manifest()
	fs.copy('LICENSE', path.join(OUTPUT_ROOT, 'LICENSE'))
	print(`Wally package prepared: {OUTPUT_ROOT}`)
end

build()
