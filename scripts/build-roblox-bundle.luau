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

local function suite_runner_source()
	return [[
local suite = nil
local runtime_context = nil
local owner = nil
local loaded = false
local loaded_value = nil

local function load()
	if loaded then return loaded_value end
	loaded = true
	if runtime_context == nil then
		error("Lutest suite runner was not configured.")
	end

	local previous_owner = runtime_context.set_registration_owner(owner)
	local ok, value = xpcall(suite, debug.traceback)
	runtime_context.set_registration_owner(previous_owner)
	if ok then
		loaded_value = if value == nil then true else value
		return loaded_value
	end

	loaded_value = {
		__lutest_suite_load_failure = true,
		error_message = value,
	}
	return loaded_value
end

return {
	configure = function(next_context, next_owner)
		runtime_context = next_context
		owner = next_owner
	end,
	register = function(callback)
		suite = callback
	end,
	load = load,
}
]]
end

local manifest_path = find_argument '--manifest'
local output_path = find_argument '--output'
local root_name = find_argument '--root-name' or 'LutestBundle'
local root_module = find_argument '--root-module'
if manifest_path == nil or output_path == nil then
	fail 'expected --manifest <path> and --output <path>'
end

local manifest = serde.decode('json', fs.readFile(manifest_path))
if type(manifest) ~= 'table' or type(manifest.files) ~= 'table' then
	fail 'manifest must contain a files array'
end

local root = roblox.Instance.new(
	if root_module == nil then 'Folder' else 'ModuleScript'
)
root.Name = root_name
local wrote_root_module = false

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

	local module = root
	if entry.relative ~= root_module then
		local segments = string.split(entry.relative, '/')
		local parent = folder_for(root, segments, #segments - 1)
		module = roblox.Instance.new(script_class(entry.relative))
		module.Name = string.gsub(segments[#segments], '%.luau$', '')
		module.Parent = parent
	else
		wrote_root_module = true
	end
	module.Source = if type(entry.source) == 'string'
		then entry.source
		else fs.readFile(entry.absolute)
	if entry.test_suite == true then
		local runner = roblox.Instance.new 'ModuleScript'
		runner.Name = '__lutest_suite_runner'
		runner.Source = suite_runner_source()
		runner.Parent = module
		module.Source = [[
local __lutest_suite_runner = require(script.__lutest_suite_runner)
local function __lutest_suite()
]] .. module.Source .. [[

end

__lutest_suite_runner.register(__lutest_suite)
return __lutest_suite_runner.load()
]]
	end
end

if root_module ~= nil and not wrote_root_module then
	fail(`manifest does not contain root module '{root_module}'`)
end

fs.writeFile(output_path, roblox.serializeModel { root })

if root_module ~= nil then
	local exported = roblox.deserializeModel(fs.readFile(output_path))[1]
	if exported == nil or exported.Name ~= root_name then
		fail 'serialized root module did not match the requested root name'
	end
	if exported:FindFirstChild 'context' == nil then
		fail 'serialized root module is missing context'
	end
	if exported:FindFirstChild 'core' == nil then
		fail 'serialized root module is missing core'
	end
end
