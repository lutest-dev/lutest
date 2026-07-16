const config = require '@runtimes/lute/config'
const lute_discovery = require '@runtimes/lute/discovery'
const fs = require '@std/fs'
const path_utils = require '@lutest/utils/path'
const t = require '@lutest_release'
const query = require '@std/syntax/query'
const syntax = require '@std/syntax'
const utils = require '@std/syntax/utils'

type LutestConfig = config.LutestConfig
type ServiceAliases = { [string]: boolean }

const function service_path(require_path: string): (string, string)
	const service, suffix = require_path:match '^([^.]+)%.(.+)$'
	if service == nil or suffix == nil then return '', '' end
	return service, suffix
end

const function is_service_call(node: syntax.AstNode, service: string): boolean
	const call = utils.isExprCall(node)
	if call == nil or #call.arguments ~= 1 then return false end

	const method = utils.isExprIndexName(call.func)
	if method == nil or method.index.text ~= 'GetService' then
		return false
	end

	const receiver = utils.isExprGlobal(method.expression)
	if receiver == nil or receiver.name.text ~= 'game' then return false end

	const argument = utils.isExprConstantString(call.arguments[1].node)
	return argument ~= nil and argument.token.text == service
end

const function local_id(local_node: syntax.AstLocal): string
	const location = local_node.name.location
	return `{local_node.name.text}:{location.beginLine}:{location.beginColumn}`
end

const function collect_service_aliases(
	ast: syntax.ParseResult,
	service: string
): ServiceAliases
	const aliases = {} :: ServiceAliases
	for _, node in query.findAllFromRoot(ast, utils.isStatLocal).nodes do
		if #node.variables ~= 1 or #node.values ~= 1 then continue end
		if not is_service_call(node.values[1].node, service) then
			continue
		end

		aliases[local_id(node.variables[1].node)] = true
	end
	return aliases
end

const function access_path(node: syntax.AstNode): (
	(syntax.AstExprGlobal | syntax.AstExprLocal)?,
	{ string }
)
	local expression = node
	const segments = {} :: { string }
	while true do
		const group = utils.isExprGroup(expression)
		if group ~= nil then
			expression = group.expression
			continue
		end

		const access = utils.isExprIndexName(expression)
		if access == nil then break end
		table.insert(segments, 1, access.index.text)
		expression = access.expression
	end

	return utils.isExprGlobal(expression) or utils.isExprLocal(expression),
		segments
end

const function has_segments(segments: { string }, path: string): boolean
	return table.concat(segments, '.') == path
end

const function matches_test_require(
	node: syntax.AstNode,
	require_path: string,
	service_aliases: ServiceAliases
): boolean
	const call = utils.isRequireCall(node)
	if call == nil or #call.arguments ~= 1 then return false end

	const root, segments = access_path(call.arguments[1].node)
	const global = if root == nil then nil else utils.isExprGlobal(root)
	if global ~= nil then
		return global.name.text == 'game'
			and has_segments(segments, require_path)
	end

	const local_ref = if root == nil then nil else utils.isExprLocal(root)
	if
		local_ref == nil
		or not service_aliases[local_id(local_ref['local'])]
	then
		return false
	end

	const _, suffix = service_path(require_path)
	return suffix ~= '' and has_segments(segments, suffix)
end

const function depends_on_test_lib(
	filepath: string,
	require_path: string
): boolean
	const ast = syntax.parse(fs.readFileToString(filepath))
	const service, _ = service_path(require_path)
	const aliases = if service == ''
		then {} :: ServiceAliases
		else collect_service_aliases(ast, service)

	return #query.findAllFromRoot(ast, function(node)
		return if matches_test_require(node, require_path, aliases)
			then true
			else nil
	end).nodes > 0
end

const function discover_suites(
	paths: { string },
	project_config: LutestConfig,
	config_path: string?
): { string }
	const candidates = lute_discovery.discover_all_files(
		paths,
		project_config,
		config_path
	)
	const suites = {} :: { string }
	for _, filepath in candidates do
		if depends_on_test_lib(filepath, project_config.require) then
			table.insert(suites, filepath)
		end
	end
	return suites
end

const function relative_paths(paths: { string }): { string }
	const result = {} :: { string }
	for _, filepath in paths do
		table.insert(result, path_utils.relative_to_cwd(filepath))
	end
	return result
end

t.test('should recognize a typed Roblox library service alias', function()
	const temp_path = path_utils.resolve_path(
		path_utils.cwd(),
		'dist/test-tmp/roblox-discovery.luau'
	)
	fs.writeStringToFile(
		temp_path,
		[[
local Storage: ReplicatedStorage = game:GetService 'ReplicatedStorage'
local t = require(Storage.Packages.lutest)
t.test("works", function() end)
]]
	)
	assert(
		depends_on_test_lib(
			temp_path,
			'ReplicatedStorage.Packages.lutest'
		)
	)
	fs.remove(temp_path)
end)

t.test('should ignore require paths in comments and strings', function()
	const temp_path = path_utils.resolve_path(
		path_utils.cwd(),
		'dist/test-tmp/roblox-non-suite.luau'
	)
	fs.writeStringToFile(
		temp_path,
		[[
-- require(game.ReplicatedStorage.Packages.lutest)
local example = "require(game.ReplicatedStorage.Packages.lutest)"
return example
]]
	)
	assert(
		not depends_on_test_lib(
			temp_path,
			'ReplicatedStorage.Packages.lutest'
		)
	)
	fs.remove(temp_path)
end)

t.test('should ignore a shadowed service alias', function()
	const temp_path = path_utils.resolve_path(
		path_utils.cwd(),
		'dist/test-tmp/roblox-shadowed-alias.luau'
	)
	fs.writeStringToFile(
		temp_path,
		[[
local Storage = game:GetService 'ReplicatedStorage'
do
	local Storage = game.Workspace
	local t = require(Storage.Packages.lutest)
end
]]
	)
	assert(
		not depends_on_test_lib(
			temp_path,
			'ReplicatedStorage.Packages.lutest'
		)
	)
	fs.remove(temp_path)
end)

t.test('should recognize a direct Roblox library require', function()
	const temp_path = path_utils.resolve_path(
		path_utils.cwd(),
		'dist/test-tmp/roblox-direct-discovery.luau'
	)
	fs.writeStringToFile(
		temp_path,
		[[
local t = require(game.ReplicatedStorage.Packages.lutest)
t.test("works", function() end)
]]
	)
	assert(
		depends_on_test_lib(
			temp_path,
			'ReplicatedStorage.Packages.lutest'
		)
	)
	fs.remove(temp_path)
end)

return {
	discover_suites = discover_suites,
	discover_all_files = lute_discovery.discover_all_files,
	relative_paths = relative_paths,
}
