const config = require '@runtimes/lute/config'
const path_utils = require '@lutest/utils/path'
const t = require '@lutest_release'
const fs = require '@std/fs'
const path = require '@std/path'
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

const function normalize_ignore_rule(line: string): string
	const normalized = line:gsub('\\', '/')
	if stringext.hasSuffix(normalized, '/') then
		return normalized:sub(1, -2)
	end

	return normalized
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
	return path_utils.normalize_path(path.relative(cwd, filepath))
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

	if not ok then return false end

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
		const entry_path = path_utils.normalize_path(
			path.join(directory, entry.name)
		)
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
		return path_utils.normalize_path(input_path)
	end

	return path_utils.normalize_path(path.join(cwd, input_path))
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
	const cwd = path_utils.cwd()
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

t.test('should prefer explicit input paths over config roots', function()
	const resolved = resolve_input_paths({
		'src',
		'tests',
	}, {
		roots = { 'packages' },
		ignore = {},
		require = '@lutest_release',
		gitignore = true,
	})

	assert(#resolved == 2)
	assert(resolved[1] == 'src')
	assert(resolved[2] == 'tests')
end)

t.test('should use config roots when no input paths are provided', function()
	const resolved = resolve_input_paths({}, {
		roots = { 'src', 'tests' },
		ignore = {},
		require = '@lutest_release',
		gitignore = true,
	})

	assert(#resolved == 2)
	assert(resolved[1] == 'src')
	assert(resolved[2] == 'tests')
end)

t.test('should discover only .luau modules requiring the test lib', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'discovery-require-filter')
	const matching_module =
		path_utils.normalize_path(path.join(temp_cwd, 'matching.luau'))
	const wrong_extension_module = path_utils.normalize_path(
		path.join(temp_cwd, 'wrong-extension.lua')
	)
	const text_file =
		path_utils.normalize_path(path.join(temp_cwd, 'notes.txt'))

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		matching_module,
		[[
local t = require("@lutest_release")

t.test("should pass", function()
	assert(true)
end)
]]
	)
	fs.writeStringToFile(
		wrong_extension_module,
		[[
local t = require("@lutest_release")

return t
]]
	)
	fs.writeStringToFile(text_file, 'not a luau module')

	const discovered = {} :: { string }
	const seen = {} :: SeenMap

	discover_path(discovered, seen, temp_cwd, temp_cwd, {}, {
		roots = { '.' },
		ignore = {},
		require = '@lutest_release',
		gitignore = false,
	})

	assert(#discovered == 1)
	assert(discovered[1] == matching_module)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should skip modules that do not require the test lib', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd = path_utils.resolve_path(
		temp_root,
		'discovery-skip-non-test-lib'
	)
	const non_matching_module = path_utils.normalize_path(
		path.join(temp_cwd, 'non-matching.luau')
	)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		non_matching_module,
		[[
local value = 41

return value
]]
	)

	const discovered = {} :: { string }
	const seen = {} :: SeenMap

	discover_path(discovered, seen, non_matching_module, temp_cwd, {}, {
		roots = { '.' },
		ignore = {},
		require = '@lutest_release',
		gitignore = false,
	})

	assert(#discovered == 0)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should dedupe files discovered through overlapping paths', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'discovery-dedupe-overlap')
	const matching_module =
		path_utils.normalize_path(path.join(temp_cwd, 'matching.luau'))

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		matching_module,
		[[
local t = require("@lutest_release")

t.test("should pass", function()
	assert(true)
end)
]]
	)

	const discovered = {} :: { string }
	const seen = {} :: SeenMap
	const project_config = {
		roots = { '.' },
		ignore = {},
		require = '@lutest_release',
		gitignore = false,
	}

	discover_path(discovered, seen, temp_cwd, temp_cwd, {}, project_config)
	discover_path(
		discovered,
		seen,
		matching_module,
		temp_cwd,
		{},
		project_config
	)

	assert(#discovered == 1)
	assert(discovered[1] == matching_module)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test(
	'should ignore configured directories without native hardcode',
	function()
		const temp_root = path_utils.resolve_path(
			path_utils.cwd(),
			'dist/test-tmp'
		)
		const temp_cwd = path_utils.resolve_path(
			temp_root,
			'discovery-native-ignores'
		)
		const src_module = path_utils.normalize_path(
			path.join(temp_cwd, 'src', 'matching.luau')
		)
		const vendor_module = path_utils.normalize_path(
			path.join(temp_cwd, 'vendor', 'ignored.luau')
		)
		const git_module = path_utils.normalize_path(
			path.join(temp_cwd, '.git', 'ignored.luau')
		)
		const packages_module = path_utils.normalize_path(
			path.join(temp_cwd, 'luau_packages', 'ignored.luau')
		)

		if fs.exists(temp_cwd) then
			fs.removeDirectory(temp_cwd, { recursive = true })
		end

		fs.createDirectory(
			path.join(temp_cwd, 'src'),
			{ makeParents = true }
		)
		fs.createDirectory(
			path.join(temp_cwd, 'vendor'),
			{ makeParents = true }
		)
		fs.createDirectory(
			path.join(temp_cwd, '.git'),
			{ makeParents = true }
		)
		fs.createDirectory(path.join(temp_cwd, 'luau_packages'), {
			makeParents = true,
		})

		fs.writeStringToFile(
			src_module,
			[[
local t = require("@lutest_release")

t.test("should pass", function()
	assert(true)
end)
]]
		)
		fs.writeStringToFile(
			vendor_module,
			[[
local t = require("@lutest_release")

return t
]]
		)
		fs.writeStringToFile(
			git_module,
			[[
local t = require("@lutest_release")

return t
]]
		)
		fs.writeStringToFile(
			packages_module,
			[[
local t = require("@lutest_release")

return t
]]
		)

		const discovered = {} :: { string }
		const seen = {} :: SeenMap

		discover_path(discovered, seen, temp_cwd, temp_cwd, {}, {
			roots = { '.' },
			ignore = { 'vendor', '.git', 'luau_packages' },
			require = '@lutest_release',
			gitignore = false,
		})

		assert(#discovered == 1)
		assert(discovered[1] == src_module)

		fs.removeDirectory(temp_cwd, { recursive = true })
	end
)

t.test('should respect discovery ignore patterns from config', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'discovery-config-ignore')
	const kept_module = path_utils.normalize_path(
		path.join(temp_cwd, 'src', 'kept.luau')
	)
	const ignored_module = path_utils.normalize_path(
		path.join(temp_cwd, 'generated', 'ignored.luau')
	)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(path.join(temp_cwd, 'src'), { makeParents = true })
	fs.createDirectory(path.join(temp_cwd, 'generated'), {
		makeParents = true,
	})

	fs.writeStringToFile(
		kept_module,
		[[
local t = require("@lutest_release")

t.test("should pass", function()
	assert(true)
end)
]]
	)
	fs.writeStringToFile(
		ignored_module,
		[[
local t = require("@lutest_release")

t.test("should be ignored", function()
	assert(true)
end)
]]
	)

	const discovered = {} :: { string }
	const seen = {} :: SeenMap

	discover_path(discovered, seen, temp_cwd, temp_cwd, {}, {
		roots = { '.' },
		ignore = { 'generated' },
		require = '@lutest_release',
		gitignore = false,
	})

	assert(#discovered == 1)
	assert(discovered[1] == kept_module)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should respect .gitignore when enabled', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd = path_utils.resolve_path(
		temp_root,
		'discovery-gitignore-enabled'
	)
	const kept_module = path_utils.normalize_path(
		path.join(temp_cwd, 'src', 'kept.luau')
	)
	const ignored_module = path_utils.normalize_path(
		path.join(temp_cwd, 'generated', 'ignored.luau')
	)
	const gitignore_path = path.join(temp_cwd, '.gitignore')

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(path.join(temp_cwd, 'src'), { makeParents = true })
	fs.createDirectory(path.join(temp_cwd, 'generated'), {
		makeParents = true,
	})

	fs.writeStringToFile(gitignore_path, 'generated\n')
	fs.writeStringToFile(
		kept_module,
		[[
local t = require("@lutest_release")

t.test("should pass", function()
	assert(true)
end)
]]
	)
	fs.writeStringToFile(
		ignored_module,
		[[
local t = require("@lutest_release")

t.test("should be ignored", function()
	assert(true)
end)
]]
	)

	const discovered = {} :: { string }
	const seen = {} :: SeenMap
	const gitignore_rules = load_gitignore_rules(temp_cwd)

	discover_path(discovered, seen, temp_cwd, temp_cwd, gitignore_rules, {
		roots = { '.' },
		ignore = {},
		require = '@lutest_release',
		gitignore = true,
	})

	assert(#discovered == 1)
	assert(discovered[1] == kept_module)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should ignore .gitignore when disabled in config', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd = path_utils.resolve_path(
		temp_root,
		'discovery-gitignore-disabled'
	)
	const kept_module = path_utils.normalize_path(
		path.join(temp_cwd, 'src', 'kept.luau')
	)
	const ignored_by_git_module = path_utils.normalize_path(
		path.join(temp_cwd, 'generated', 'kept-by-config.luau')
	)
	const gitignore_path = path.join(temp_cwd, '.gitignore')

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(path.join(temp_cwd, 'src'), { makeParents = true })
	fs.createDirectory(path.join(temp_cwd, 'generated'), {
		makeParents = true,
	})

	fs.writeStringToFile(gitignore_path, 'generated\n')
	fs.writeStringToFile(
		kept_module,
		[[
local t = require("@lutest_release")

t.test("should pass", function()
	assert(true)
end)
]]
	)
	fs.writeStringToFile(
		ignored_by_git_module,
		[[
local t = require("@lutest_release")

t.test("should still be discovered", function()
	assert(true)
end)
]]
	)

	const discovered = {} :: { string }
	const seen = {} :: SeenMap
	const gitignore_rules = load_gitignore_rules(temp_cwd)

	discover_path(discovered, seen, temp_cwd, temp_cwd, gitignore_rules, {
		roots = { '.' },
		ignore = {},
		require = '@lutest_release',
		gitignore = false,
	})

	table.sort(discovered)
	assert(#discovered == 2)
	assert(discovered[1] == ignored_by_git_module)
	assert(discovered[2] == kept_module)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should skip unparsable modules during discovery', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd = path_utils.resolve_path(
		temp_root,
		'discovery-unparsable-module'
	)
	const invalid_module =
		path_utils.normalize_path(path.join(temp_cwd, 'broken.luau'))

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		invalid_module,
		[[
local t = require("@lutest_release")

t.test("should break", function()
	assert(true)
end
]]
	)

	const discovered = {} :: { string }
	const seen = {} :: SeenMap

	discover_path(discovered, seen, invalid_module, temp_cwd, {}, {
		roots = { '.' },
		ignore = {},
		require = '@lutest_release',
		gitignore = false,
	})

	assert(#discovered == 0)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should keep discovered files sorted', function()
	const temp_cwd = path_utils.resolve_path(
		path_utils.cwd(),
		'discovery-sort-fixture'
	)
	const later_module =
		path_utils.normalize_path(path.join(temp_cwd, 'zeta.luau'))
	const earlier_module =
		path_utils.normalize_path(path.join(temp_cwd, 'alpha.luau'))

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		later_module,
		[[
local t = require("@lutest_release")

t.test("should pass later", function()
	assert(true)
end)
]]
	)
	fs.writeStringToFile(
		earlier_module,
		[[
local t = require("@lutest_release")

t.test("should pass earlier", function()
	assert(true)
end)
]]
	)

	const discovered = discover_files {
		later_module,
		earlier_module,
	}

	assert(#discovered == 2)
	assert(discovered[1] == earlier_module)
	assert(discovered[2] == later_module)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

return {
	discover_files = discover_files,
}
