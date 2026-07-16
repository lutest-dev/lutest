local function lune_require(name)
	return require(`@lune/{name}`) :: any
end

local fs = lune_require 'fs'
local process = lune_require 'process'
local roblox = lune_require 'roblox'
local serde = lune_require 'serde'

local function fail(message)
	error(`build-roblox-bundle: {message}`, 0)
end

local function find_argument(name)
	for index, value in process.args do
		if value == name then return process.args[index + 1] end
	end
	return nil
end

local function folder_for(root, segments, count)
	local current = root
	for index = 1, count do
		local name = segments[index]
		local child = current:FindFirstChild(name)
		if child == nil then
			child = roblox.Instance.new 'Folder'
			child.Name = name
			child.Parent = current
		end
		current = child
	end
	return current
end

local function script_class(relative_path)
	if string.match(relative_path, '%.client%.luau$') then
		return 'LocalScript'
	end
	if string.match(relative_path, '%.server%.luau$') then
		return 'Script'
	end
	return 'ModuleScript'
end

local manifest_path = find_argument '--manifest'
local output_path = find_argument '--output'
if manifest_path == nil or output_path == nil then
	fail 'expected --manifest <path> and --output <path>'
end

local manifest = serde.decode('json', fs.readFile(manifest_path))
if type(manifest) ~= 'table' or type(manifest.files) ~= 'table' then
	fail 'manifest must contain a files array'
end

local root = roblox.Instance.new 'Folder'
root.Name = 'LutestBundle'

for _, entry in manifest.files do
	if type(entry) ~= 'table' then
		fail 'manifest file entry must be an object'
	end
	if
		type(entry.absolute) ~= 'string'
		or type(entry.relative) ~= 'string'
	then
		fail 'manifest file entry requires absolute and relative strings'
	end

	local segments = string.split(entry.relative, '/')
	local parent = folder_for(root, segments, #segments - 1)
	local module = roblox.Instance.new(script_class(entry.relative))
	module.Name = string.gsub(segments[#segments], '%.luau$', '')
	module.Source = if type(entry.source) == 'string'
		then entry.source
		else fs.readFile(entry.absolute)
	if entry.test_suite == true then
		module.Source = [[
local function __lutest_suite()
]] .. module.Source .. [[

end

local __lutest_ok, __lutest_value = xpcall(__lutest_suite, debug.traceback)
return {
	__lutest_suite_load_result = true,
	ok = __lutest_ok,
	value = __lutest_value,
}
]]
	end
	module.Parent = parent
end

fs.writeFile(output_path, roblox.serializeModel { root })
