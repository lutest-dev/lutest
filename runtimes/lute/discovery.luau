const fs = require '@std/fs'
const path = require '@std/path'
const process = require '@std/process'
const stringext = require '@std/stringext'

const IGNORE_SEGMENTS = {
	'.git',
	'luau_packages',
	'vendor',
}

const function normalize_path(value: path.Pathlike): string
	const formatted = path.format(path.normalize(value))
	const normalized = formatted:gsub('\\', '/')
	return normalized
end

const function is_test_module(filepath: string): boolean
	return stringext.hasSuffix(filepath, '.spec.luau')
		or stringext.hasSuffix(filepath, '.test.luau')
end

const function should_ignore(filepath: string): boolean
	for _, segment in IGNORE_SEGMENTS do
		if
			filepath == segment
			or filepath:find(`/{segment}/`, 1, true)
			or stringext.hasSuffix(filepath, `/{segment}`)
		then
			return true
		end
	end

	return false
end

const function add_file(
	results: { string },
	seen: { [string]: boolean },
	filepath: string
)
	if seen[filepath] then return end
	if should_ignore(filepath) then return end
	if not is_test_module(filepath) then return end

	seen[filepath] = true
	table.insert(results, filepath)
end

const function walk_directory(
	results: { string },
	seen: { [string]: boolean },
	directory: string
)
	const iterator =
		fs.walk(path.normalize(directory), { recursive = true })
	local entry = iterator()

	while entry do
		if fs.type(entry) ~= 'file' then
			entry = iterator()
			continue
		end

		add_file(results, seen, normalize_path(entry))

		entry = iterator()
	end
end

const function discover_files(paths: { string }): { string }
	const discovered = {} :: { string }
	const seen = {} :: { [string]: boolean }
	const cwd = process.cwd()

	for _, input_path in paths do
		const resolved_path = if path.isAbsolute(input_path)
			then input_path
			else path.join(cwd, input_path)
		const normalized_path = normalize_path(resolved_path)

		if should_ignore(normalized_path) then continue end

		const file_type = fs.type(normalized_path)

		if file_type == 'file' then
			add_file(discovered, seen, normalized_path)
			continue
		end

		if file_type == 'dir' then
			walk_directory(discovered, seen, normalized_path)
		end
	end

	table.sort(discovered)
	return discovered
end

return {
	discover_files = discover_files,
}
