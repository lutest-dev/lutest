const fs = require '@std/fs'
const path = require '@std/path'
const process = require '@std/process'
const query = require '@std/syntax/query'
const stringext = require '@std/stringext'
const syntax = require '@std/syntax'
const utils = require '@std/syntax/utils'

type GitignoreRule = {
	pattern: string,
	match_anywhere: boolean,
}

type GitignoreRules = { GitignoreRule }
type SeenMap = { [string]: boolean }

const GITIGNORE_PATH = '.gitignore'
const TEST_LIB_ALIAS = '@lib'

const IGNORE_SEGMENTS = {
	'.git',
	'luau_packages',
	'vendor',
}

const function normalize_path(value: path.Pathlike): string
	const formatted = path.format(path.normalize(value))
	return (formatted:gsub('\\', '/'))
end

const function normalize_ignore_rule(line: string): string
	const normalized = line:gsub('\\', '/')
	if stringext.hasSuffix(normalized, '/') then
		return normalized:sub(1, -2)
	end

	return normalized
end

const function load_gitignore_rules(cwd: string): GitignoreRules
	const gitignore_path = path.join(cwd, GITIGNORE_PATH)
	if not fs.exists(gitignore_path) then return {} end

	const rules = {} :: GitignoreRules
	const contents = fs.readFileToString(gitignore_path)

	for _, line in contents:split '\n' do
		const trimmed = stringext.trim(line)
		if trimmed == '' then continue end
		if stringext.hasPrefix(trimmed, '#') then continue end
		if stringext.hasPrefix(trimmed, '!') then continue end

		const pattern = normalize_ignore_rule(trimmed)
		if pattern == '' then continue end

		table.insert(rules, {
			pattern = pattern,
			match_anywhere = not pattern:find('/', 1, true),
		})
	end

	return rules
end

const function matches_segment(filepath: string, segment: string): boolean
	return filepath == segment
		or filepath:find(`/{segment}/`, 1, true) ~= nil
		or stringext.hasSuffix(filepath, `/{segment}`)
end

const function is_luau_module(filepath: string): boolean
	return stringext.hasSuffix(filepath, '.luau')
end

const function matches_native_ignore(filepath: string): boolean
	for _, segment in IGNORE_SEGMENTS do
		if matches_segment(filepath, segment) then return true end
	end

	return false
end

const function matches_gitignore_rule(
	relative_path: string,
	rule: GitignoreRule
): boolean
	if rule.match_anywhere then
		return relative_path == rule.pattern
			or relative_path:find(`/{rule.pattern}/`, 1, true) ~= nil
			or stringext.hasSuffix(relative_path, `/{rule.pattern}`)
	end

	return relative_path == rule.pattern
		or stringext.hasPrefix(relative_path, `{rule.pattern}/`)
end

const function matches_gitignore(
	filepath: string,
	cwd: string,
	gitignore_rules: GitignoreRules
): boolean
	const relative_path = normalize_path(path.relative(cwd, filepath))

	for _, rule in gitignore_rules do
		if matches_gitignore_rule(relative_path, rule) then
			return true
		end
	end

	return false
end

const function should_ignore(
	filepath: string,
	cwd: string,
	gitignore_rules: GitignoreRules
): boolean
	if matches_native_ignore(filepath) then return true end
	return matches_gitignore(filepath, cwd, gitignore_rules)
end

const function matches_test_lib_require(node: syntax.AstNode): boolean
	const call = utils.isRequireCall(node)
	if call == nil then return false end
	if #call.arguments ~= 1 then return false end

	const argument = utils.isExprConstantString(call.arguments[1].node)
	if argument == nil then return false end

	return argument.token.text == TEST_LIB_ALIAS
end

const function depends_on_test_lib(filepath: string): boolean
	const source = fs.readFileToString(filepath)
	local parse_result = nil :: syntax.ParseResult?
	local parse_error = nil :: string?

	const ok = xpcall(function()
		parse_result = syntax.parse(source)
	end, function(message)
		parse_error = tostring(message)
		return parse_error
	end)

	if not ok then
		warn(
			`warning: failed to parse '{filepath}' during discovery: {parse_error}`
		)
		return false
	end

	const ast = parse_result :: syntax.ParseResult
	return #query.findAllFromRoot(ast, function(node)
		return if matches_test_lib_require(node) then true else nil
	end).nodes > 0
end

const function add_file(
	results: { string },
	seen: SeenMap,
	filepath: string,
	cwd: string,
	gitignore_rules: GitignoreRules
)
	if seen[filepath] then return end
	if should_ignore(filepath, cwd, gitignore_rules) then return end
	if not is_luau_module(filepath) then return end
	if not depends_on_test_lib(filepath) then return end

	seen[filepath] = true
	table.insert(results, filepath)
end

const function walk_directory(
	results: { string },
	seen: SeenMap,
	directory: string,
	cwd: string,
	gitignore_rules: GitignoreRules
)
	for _, entry in fs.listDirectory(directory) do
		const entry_path =
			normalize_path(path.join(directory, entry.name))
		if should_ignore(entry_path, cwd, gitignore_rules) then
			continue
		end

		if entry.type == 'dir' then
			walk_directory(
				results,
				seen,
				entry_path,
				cwd,
				gitignore_rules
			)
			continue
		end

		if entry.type ~= 'file' then continue end
		add_file(results, seen, entry_path, cwd, gitignore_rules)
	end
end

const function discover_files(paths: { string }): { string }
	const discovered = {} :: { string }
	const seen = {} :: SeenMap
	const cwd = normalize_path(process.cwd())
	const gitignore_rules = load_gitignore_rules(cwd)

	for _, input_path in paths do
		const resolved_path = if path.isAbsolute(input_path)
			then input_path
			else path.join(cwd, input_path)
		const normalized_path = normalize_path(resolved_path)
		if should_ignore(normalized_path, cwd, gitignore_rules) then
			continue
		end

		const file_type = fs.type(normalized_path)
		if file_type == 'file' then
			add_file(
				discovered,
				seen,
				normalized_path,
				cwd,
				gitignore_rules
			)
			continue
		end

		if file_type == 'dir' then
			walk_directory(
				discovered,
				seen,
				normalized_path,
				cwd,
				gitignore_rules
			)
		end
	end

	table.sort(discovered)
	return discovered
end

return {
	discover_files = discover_files,
}
