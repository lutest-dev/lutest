const config = require '@runtimes/lute/config'
const lute_discovery = require '@runtimes/lute/discovery'
const fs = require '@std/fs'
const path_utils = require '@lutest/utils/path'
const t = require '@lutest_release'

type LutestConfig = config.LutestConfig

const function require_marker(path: string): string
	return `require({path})`
end

const function service_path(require_path: string): (string, string)
	const service, suffix = require_path:match '^([^.]+)%.(.+)$'
	if service == nil or suffix == nil then return '', '' end
	return service, suffix
end

const function service_aliases(source: string, service: string): { string }
	const aliases = {} :: { string }
	for _, pattern in
		{
			`local([_%a][_%w]*)=game:GetService%(['"]{service}['"]%)`,
			`local([_%a][_%w]*)=game:GetService['"]{service}['"]`,
		}
	do
		for alias in source:gmatch(pattern) do
			table.insert(aliases, alias)
		end
	end
	return aliases
end

const function depends_on_test_lib(
	filepath: string,
	require_path: string
): boolean
	const source = fs.readFileToString(filepath)
	const normalized = source:gsub('%s+', '')
	if normalized:find(require_marker(`game.{require_path}`), 1, true) then
		return true
	end

	const service, suffix = service_path(require_path)
	if service == '' then return false end
	for _, alias in service_aliases(normalized, service) do
		if
			normalized:find(
				require_marker(`{alias}.{suffix}`),
				1,
				true
			)
		then
			return true
		end
	end
	return false
end

const function discover_suites(
	paths: { string },
	project_config: LutestConfig
): { string }
	const candidates =
		lute_discovery.discover_all_files(paths, project_config)
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

t.test('should recognize a Roblox library service alias', function()
	const temp_path = path_utils.resolve_path(
		path_utils.cwd(),
		'dist/test-tmp/roblox-discovery.luau'
	)
	fs.writeStringToFile(
		temp_path,
		[[
local ReplicatedStorage = game:GetService 'ReplicatedStorage'
local t = require(ReplicatedStorage.Packages.lutest)
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
