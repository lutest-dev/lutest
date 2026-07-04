const fs = require '@std/fs'
const path = require '@std/path'
const process = require '@std/process'
const t = require '@lutest_release'

const function normalize_path(value: path.Pathlike): string
	const formatted = path.format(path.normalize(value))
	return (formatted:gsub('\\', '/'))
end

const function cwd(): string
	return normalize_path(process.cwd())
end

const function resolve_from_cwd(value: string): string
	if path.isAbsolute(value) then return normalize_path(value) end

	return normalize_path(path.join(cwd(), value))
end

const function relative_to_cwd(value: string): string
	return normalize_path(path.relative(cwd(), value))
end

const function resolve_path(base: string, value: string): string
	if path.isAbsolute(value) then return normalize_path(value) end

	return normalize_path(path.join(base, value))
end

const function ensure_directory(directory: string)
	if directory == '' or directory == '.' then return end
	if fs.exists(directory) then return end

	fs.createDirectory(directory, {
		makeParents = true,
	})
end

t.test('should normalize separators and dot segments', function()
	const normalized = normalize_path 'foo\\bar/../baz/./qux.luau'

	assert(normalized == 'foo/baz/qux.luau')
end)

t.test('should resolve relative paths from cwd', function()
	const expected =
		normalize_path(path.join(process.cwd(), 'src/module.luau'))
	const resolved = resolve_from_cwd 'src/module.luau'

	assert(resolved == expected)
end)

t.test('should preserve absolute paths when resolving', function()
	const absolute_path =
		normalize_path(path.join(process.cwd(), 'src/module.luau'))
	const resolved_from_cwd = resolve_from_cwd(absolute_path)
	const resolved_from_base = resolve_path('ignored/base', absolute_path)

	assert(resolved_from_cwd == absolute_path)
	assert(resolved_from_base == absolute_path)
end)

t.test('should compute paths relative to cwd', function()
	const absolute_path =
		normalize_path(path.join(process.cwd(), 'src/module.luau'))
	const relative_path = relative_to_cwd(absolute_path)

	assert(relative_path == 'src/module.luau')
end)

t.test('should create missing directories and ignore existing ones', function()
	const temp_root = resolve_path(cwd(), 'dist/test-tmp')
	const fixture_root = resolve_path(temp_root, 'path-ensure-directory')
	const temp_directory = resolve_path(fixture_root, 'nested/child')

	if fs.exists(fixture_root) then
		fs.removeDirectory(fixture_root, {
			recursive = true,
		})
	end

	ensure_directory(temp_directory)
	assert(fs.exists(temp_directory))

	ensure_directory(temp_directory)
	assert(fs.exists(temp_directory))

	fs.removeDirectory(fixture_root, {
		recursive = true,
	})
end)

return {
	cwd = cwd,
	ensure_directory = ensure_directory,
	normalize_path = normalize_path,
	relative_to_cwd = relative_to_cwd,
	resolve_from_cwd = resolve_from_cwd,
	resolve_path = resolve_path,
}
