const fs = require '@std/fs'
const path = require '@std/path'
const path_utils = require '@lutest/utils/path'

const MAGIC_PATTERN = '[%*%?%[]'
const LUA_MAGIC = {
	['^'] = true,
	['$'] = true,
	['('] = true,
	[')'] = true,
	['%'] = true,
	['.'] = true,
	['['] = true,
	[']'] = true,
	['*'] = true,
	['+'] = true,
	['-'] = true,
	['?'] = true,
}

const function has_magic(value: string): boolean
	return value:find(MAGIC_PATTERN) ~= nil
end

const function split_segments(value: string): { string }
	const segments = {} :: { string }
	for segment in value:gmatch '[^/]+' do
		table.insert(segments, segment)
	end
	return segments
end

const function segment_to_pattern(segment: string): string
	const parts = { '^' } :: { string }
	local index = 1

	while index <= #segment do
		const char = segment:sub(index, index)
		if char == '*' then
			table.insert(parts, '.*')
			index += 1
			continue
		end
		if char == '?' then
			table.insert(parts, '.')
			index += 1
			continue
		end
		if char == '[' then
			const class_end = segment:find(']', index + 1, true)
			if class_end ~= nil then
				local body =
					segment:sub(index + 1, class_end - 1)
				if body:sub(1, 1) == '!' then
					body = `^{body:sub(2)}`
				end
				table.insert(parts, `[{body}]`)
				index = class_end + 1
				continue
			end
		end

		if LUA_MAGIC[char] then
			table.insert(parts, `%{char}`)
		else
			table.insert(parts, char)
		end
		index += 1
	end

	table.insert(parts, '$')
	return table.concat(parts)
end

const function segment_matches(segment: string, name: string): boolean
	return name:find(segment_to_pattern(segment)) ~= nil
end

const function match_segments(
	pattern_segments: { string },
	pattern_index: number,
	subject_segments: { string },
	subject_index: number
): boolean
	if pattern_index > #pattern_segments then
		return subject_index > #subject_segments
	end

	const segment = pattern_segments[pattern_index]
	if segment == '**' then
		for cursor = subject_index, #subject_segments + 1 do
			if
				match_segments(
					pattern_segments,
					pattern_index + 1,
					subject_segments,
					cursor
				)
			then
				return true
			end
		end
		return false
	end

	if subject_index > #subject_segments then return false end
	if not segment_matches(segment, subject_segments[subject_index]) then
		return false
	end

	return match_segments(
		pattern_segments,
		pattern_index + 1,
		subject_segments,
		subject_index + 1
	)
end

--- Matches a `/`-delimited `subject` path against a glob `pattern` without
--- touching the filesystem. Supports `*`, `?`, `[...]` within a segment and
--- `**` spanning zero or more segments. Both sides are matched in full.
const function matches(pattern: string, subject: string): boolean
	return match_segments(
		split_segments(pattern),
		1,
		split_segments(subject),
		1
	)
end

const function expand_segments(
	current: string,
	segments: { string },
	index: number,
	seen: { [string]: boolean },
	results: { string }
)
	if index > #segments then
		if seen[current] then return end
		if not fs.exists(current) then return end
		seen[current] = true
		table.insert(results, current)
		return
	end

	const segment = segments[index]
	if segment == '**' then
		expand_segments(current, segments, index + 1, seen, results)
		if not fs.exists(current) or fs.type(current) ~= 'dir' then
			return
		end
		for _, entry in fs.listDirectory(current) do
			if entry.type ~= 'dir' and entry.type ~= 'link' then
				continue
			end
			const child = path_utils.normalize_path(
				path.join(current, entry.name)
			)
			expand_segments(child, segments, index, seen, results)
		end
		return
	end

	if not has_magic(segment) then
		const child =
			path_utils.normalize_path(path.join(current, segment))
		expand_segments(child, segments, index + 1, seen, results)
		return
	end

	if not fs.exists(current) or fs.type(current) ~= 'dir' then return end
	for _, entry in fs.listDirectory(current) do
		if not segment_matches(segment, entry.name) then continue end
		const child = path_utils.normalize_path(
			path.join(current, entry.name)
		)
		expand_segments(child, segments, index + 1, seen, results)
	end
end

const function literal_prefix(pattern: string): (string, string)
	const magic_start = pattern:find(MAGIC_PATTERN)
	if magic_start == nil then return pattern, '' end

	const boundary = pattern:sub(1, magic_start):match '.*()/'
	if boundary == nil then return '', pattern end

	return pattern:sub(1, boundary - 1), pattern:sub(boundary + 1)
end

--- Expands a glob `pattern` into the concrete filesystem paths it matches.
--- Relative patterns resolve against `base`. Supports `*`, `?`, `[...]`
--- character classes within a path segment, and `**` across segments. Returns
--- sorted, normalized absolute paths for both files and directories.
const function expand(pattern: string, base: string): { string }
	const resolved = path_utils.resolve_path(base, pattern)
	const start, remainder = literal_prefix(resolved)
	const start_dir = if start == '' then '/' else start

	const results = {} :: { string }
	const seen = {} :: { [string]: boolean }
	expand_segments(start_dir, split_segments(remainder), 1, seen, results)
	table.sort(results)
	return results
end

return {
	expand = expand,
	has_magic = has_magic,
	matches = matches,
	segment_matches = segment_matches,
}
