const config = require '@runtimes/lute/config'
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
type LutestConfig = config.LutestConfig

const GITIGNORE_PATH = '.gitignore'

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

const function matches_segment(filepath: string, segment: string): boolean
	return filepath == segment
		or filepath:find(`/{segment}/`, 1, true) ~= nil
		or stringext.hasSuffix(filepath, `/{segment}`)
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

const function relative_path_from_cwd(filepath: string, cwd: string): string
	return normalize_path(path.relative(cwd, filepath))
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

const function matches_native_ignore(filepath: string): boolean
	for _, segment in IGNORE_SEGMENTS do
		if matches_segment(filepath, segment) then return true end
	end

	return false
end

const function matches_config_ignore(
	relative_path: string,
	patterns: { string }
): boolean
	for _, pattern in patterns do
		const normalized_pattern = normalize_ignore_rule(pattern)
		if normalized_pattern == '' then continue end

		if
			matches_gitignore_rule(relative_path, {
				pattern = normalized_pattern,
				match_anywhere = not normalized_pattern:find(
					'/',
					1,
					true
				),
			})
		then
			return true
		end
	end

	return false
end

const function matches_gitignore(
	relative_path: string,
	gitignore_rules: GitignoreRules
): boolean
	for _, rule in gitignore_rules do
		if matches_gitignore_rule(relative_path, rule) then
			return true
		end
	end

	return false
end

const function should_prune(
	filepath: string,
	cwd: string,
	gitignore_rules: GitignoreRules,
	project_config: LutestConfig
): boolean
	if matches_native_ignore(filepath) then return true end

	const relative_path = relative_path_from_cwd(filepath, cwd)
	if matches_config_ignore(relative_path, project_config.ignore) then
		return true
	end

	if not project_config.gitignore then return false end
	return matches_gitignore(relative_path, gitignore_rules)
end

const function is_luau_module(filepath: string): boolean
	return stringext.hasSuffix(filepath, '.luau')
end

const function matches_test_require(
	node: syntax.AstNode,
	test_require_path: string
): boolean
	const call = utils.isRequireCall(node)
	if call == nil then return false end
	if #call.arguments ~= 1 then return false end

	const argument = utils.isExprConstantString(call.arguments[1].node)
	if argument == nil then return false end

	return argument.token.text == test_require_path
end

const function depends_on_test_lib(
	filepath: string,
	test_require_path: string
): boolean
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
		return if matches_test_require(node, test_require_path)
			then true
			else nil
	end).nodes > 0
end

const function add_file(
	results: { string },
	seen: SeenMap,
	filepath: string,
	cwd: string,
	gitignore_rules: GitignoreRules,
	project_config: LutestConfig
)
	if seen[filepath] then return end
	if should_prune(filepath, cwd, gitignore_rules, project_config) then
		return
	end
	if not is_luau_module(filepath) then return end
	if not depends_on_test_lib(filepath, project_config.require) then
		return
	end

	seen[filepath] = true
	table.insert(results, filepath)
end

const function walk_directory(
	results: { string },
	seen: SeenMap,
	directory: string,
	cwd: string,
	gitignore_rules: GitignoreRules,
	project_config: LutestConfig
)
	for _, entry in fs.listDirectory(directory) do
		const entry_path =
			normalize_path(path.join(directory, entry.name))
		if
			should_prune(
				entry_path,
				cwd,
				gitignore_rules,
				project_config
			)
		then
			continue
		end

		if entry.type == 'dir' then
			walk_directory(
				results,
				seen,
				entry_path,
				cwd,
				gitignore_rules,
				project_config
			)
			continue
		end

		if entry.type ~= 'file' then continue end
		add_file(
			results,
			seen,
			entry_path,
			cwd,
			gitignore_rules,
			project_config
		)
	end
end

const function resolve_input_paths(
	paths: { string },
	project_config: LutestConfig
): { string }
	if #paths > 0 then return paths end
	if #project_config.roots > 0 then return project_config.roots end

	return { '.' }
end

const function resolve_input_path(input_path: string, cwd: string): string
	if path.isAbsolute(input_path) then
		return normalize_path(input_path)
	end

	return normalize_path(path.join(cwd, input_path))
end

const function discover_path(
	results: { string },
	seen: SeenMap,
	input_path: string,
	cwd: string,
	gitignore_rules: GitignoreRules,
	project_config: LutestConfig
)
	const resolved_path = resolve_input_path(input_path, cwd)
	if
		should_prune(
			resolved_path,
			cwd,
			gitignore_rules,
			project_config
		)
	then
		return
	end

	const file_type = fs.type(resolved_path)
	if file_type == 'file' then
		add_file(
			results,
			seen,
			resolved_path,
			cwd,
			gitignore_rules,
			project_config
		)
		return
	end

	if file_type == 'dir' then
		walk_directory(
			results,
			seen,
			resolved_path,
			cwd,
			gitignore_rules,
			project_config
		)
	end
end

const function discover_files(paths: { string }): { string }
	const discovered = {} :: { string }
	const seen = {} :: SeenMap
	const cwd = normalize_path(process.cwd())
	const gitignore_rules = load_gitignore_rules(cwd)
	const project_config = config.load_config(cwd)

	for _, input_path in resolve_input_paths(paths, project_config) do
		discover_path(
			discovered,
			seen,
			input_path,
			cwd,
			gitignore_rules,
			project_config
		)
	end

	table.sort(discovered)
	return discovered
end

return {
	discover_files = discover_files,
}
