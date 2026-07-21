const bundle = require '@self/bundle'
const config = require '@runtimes/lute/config'
const discovery = require '@self/discovery'
const errors = require '@core/errors'
const rojo = require '@self/rojo'
const ui = require '@lutest/utils/ui'
const fs = require '@std/fs'
const path = require '@std/path'
const path_utils = require '@lutest/utils/path'
const t = require '@lutest_release'

type TreeNode = {
	children: { [string]: TreeNode },
	file: bundle.BundleFile?,
}

const function new_node(): TreeNode
	return {
		children = {},
		file = nil,
	}
end

const function module_name(relative_path: string): string
	const name = relative_path
		:gsub('%.client%.lua[u]?$', '')
		:gsub('%.server%.lua[u]?$', '')
		:gsub('%.lua[u]?$', '')
	return name
end

const function module_class(relative_path: string): string
	if relative_path:match '%.client%.lua[u]?$' then
		return 'LocalScript'
	end
	if relative_path:match '%.server%.lua[u]?$' then return 'Script' end
	return 'ModuleScript'
end

const function ordered_names(children: { [string]: TreeNode }): { string }
	const names = {} :: { string }
	for name in children do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

const function add_file(root: TreeNode, file: bundle.BundleFile)
	local current = root
	for _, segment in file.relative:split '/' do
		const name = module_name(segment)
		local child = current.children[name]
		if child == nil then
			child = new_node()
			current.children[name] = child
		end
		current = child
	end
	current.file = file
end

const function tree(files: { bundle.BundleFile }): TreeNode
	const root = new_node()
	for _, file in files do
		add_file(root, file)
	end
	return root
end

const function node_label(name: string, node: TreeNode): string
	if node.file == nil then return name end

	const class = module_class(node.file.absolute)
	if not node.file.test_suite then
		return `{name} {ui.muted(`[{class}]`)}`
	end

	return `{name} {ui.muted(`[{class}, `)}{ui.accent 'suite'}{ui.muted ']'}`
end

const function render_children(
	lines: { string },
	node: TreeNode,
	prefix: string
)
	const names = ordered_names(node.children)
	for index, name in names do
		const child = node.children[name]
		const last = index == #names
		const branch = if last then '┗━' else '┣━'
		table.insert(
			lines,
			`{ui.accent(`{prefix}{branch}`)} {node_label(
				name,
				child
			)}`
		)
		if next(child.children) == nil then continue end
		const child_prefix = prefix .. (if last then '   ' else '┃  ')
		render_children(lines, child, child_prefix)
	end
end

const function format(
	config_path: string?,
	planned_files: { bundle.BundleFile },
	project_file_count: number,
	suite_paths: { string }
): string
	const lines = {
		ui.section 'Roblox bundle layout',
		'',
		`  {ui.muted 'config'}  {config_path or 'lutest.toml'}`,
		`  {ui.muted 'files'}   {project_file_count} {ui.muted '· suites'} {#suite_paths}`,
		'',
		'LutestBundle',
	} :: { string }
	render_children(lines, tree(planned_files), '')
	table.insert(lines, '')
	table.insert(
		lines,
		ui.passed(
			`{project_file_count} project file{if project_file_count
					== 1
				then ''
				else 's'} will be bundled. Nothing was uploaded.`
		)
	)
	return table.concat(lines, '\n')
end

const function project_files(paths: { string }): { bundle.BundleFile }
	const files = {} :: { bundle.BundleFile }
	for _, absolute in paths do
		table.insert(files, {
			absolute = absolute,
			relative = (discovery.relative_paths { absolute })[1],
		})
	end
	return files
end

const function inspect(
	paths: { string },
	config_path: string?,
	library_root: string?
): string
	const discovery_config, roblox_config =
		config.load_roblox_config(config_path)
	const suites =
		discovery.discover_suites(paths, discovery_config, config_path)
	const files =
		discovery.discover_all_files({}, discovery_config, config_path)
	const project = rojo.map_files(
		project_files(files),
		roblox_config.rojo_project,
		config_path
	)
	return format(
		config_path,
		bundle.planned_files(project, suites, library_root),
		#project,
		bundle.test_suite_paths(project, suites)
	)
end

t.test('should render connected module branches and suite labels', function()
	const output = errors.strip_ansi(format('lutest.toml', {
		{
			absolute = 'game/shared/inventory.luau',
			relative = 'game/shared/inventory.luau',
		},
		{
			absolute = 'tests/inventory_flow.luau',
			relative = 'tests/inventory_flow.luau',
			test_suite = true,
		},
		{
			absolute = 'game/server/inventory_service.server.luau',
			relative = 'game/server/inventory_service.server.luau',
		},
		{
			absolute = 'game/client/hud.client.lua',
			relative = 'StarterPlayer/StarterPlayerScripts/hud',
		},
	}, 3, { 'tests/inventory_flow.luau' }))

	assert(output:find('┣━ game', 1, true) ~= nil)
	assert(output:find('┃  ┗━ shared', 1, true) ~= nil)
	assert(output:find('inventory_service [Script]', 1, true) ~= nil)
	assert(output:find('hud [LocalScript]', 1, true) ~= nil)
	assert(output:find('┗━ tests', 1, true) ~= nil)
	assert(
		output:find('inventory_flow [ModuleScript, suite]', 1, true)
			~= nil
	)
	assert(output:find('Nothing was uploaded.', 1, true) ~= nil)
end)

t.test('should use roots relative to a nested Roblox config', function()
	const temp_root = path_utils.resolve_path(
		path_utils.cwd(),
		'dist/test-tmp/roblox-debug-nested-config'
	)
	const config_directory =
		path_utils.resolve_path(temp_root, 'games/arena')
	const config_path =
		path_utils.resolve_path(config_directory, 'lutest.toml')
	const suite_path =
		path_utils.resolve_path(config_directory, 'src/ok.luau')
	const library_root = path_utils.resolve_path(temp_root, 'library')

	if fs.exists(temp_root) then
		fs.removeDirectory(temp_root, { recursive = true })
	end
	fs.createDirectory(path.dirname(suite_path), { makeParents = true })
	fs.writeStringToFile(
		config_path,
		[[
[discovery.roblox]
require = "ReplicatedStorage.Packages.lutest"
roots = ["src"]

[roblox]
universe_id = 1
place_id = 2
]]
	)
	fs.writeStringToFile(
		suite_path,
		[[
local t = require(game.ReplicatedStorage.Packages.lutest)

t.test("should pass", function() end)
]]
	)
	for _, relative_path in
		{
			'init.luau',
			'context.luau',
			'registry.luau',
			'core/types.luau',
			'core/executor.luau',
		}
	do
		const library_path =
			path_utils.resolve_path(library_root, relative_path)
		fs.createDirectory(path.dirname(library_path), {
			makeParents = true,
		})
		fs.writeStringToFile(library_path, 'return {}')
	end

	const output = errors.strip_ansi(inspect({}, config_path, library_root))
	assert(output:find('ok [ModuleScript, suite]', 1, true) ~= nil)

	fs.removeDirectory(temp_root, { recursive = true })
end)

return {
	inspect = inspect,
}
