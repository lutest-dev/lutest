const fs = require '@std/fs'
const path = require '@std/path'
const process = require '@std/process'

const function normalize_path(value: path.Pathlike): string
	const formatted = path.format(value):gsub('\\', '/')
	const normalized = path.format(path.normalize(formatted))

	return (normalized:gsub('\\', '/'))
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

return {
	cwd = cwd,
	ensure_directory = ensure_directory,
	normalize_path = normalize_path,
	relative_to_cwd = relative_to_cwd,
	resolve_from_cwd = resolve_from_cwd,
	resolve_path = resolve_path,
}
