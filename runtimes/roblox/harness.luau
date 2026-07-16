const t = require '@lutest_release'

type HarnessInput = {
	test_paths: { string },
	require_path: string,
	mode: 'test' | 'todo',
}

const function quote(value: string): string
	return string.format('%q', value)
end

const function render_paths(paths: { string }): string
	const quoted = {} :: { string }
	for _, path in paths do
		table.insert(quoted, quote(path))
	end
	return `{table.concat(quoted, ', ')}`
end

const function generate(input: HarnessInput): string
	return [[
local arguments = ({ ... })[1]
local SerializationService = game:GetService("SerializationService")
local HttpService = game:GetService("HttpService")
local bundle_roots = SerializationService:DeserializeInstancesAsync(arguments.BinaryInput)
local bundle_root = bundle_roots[1]
local library_require_path = ]] .. quote(
		input.require_path:gsub('^game%.', '')
	) .. [[
local test_paths = {]] .. render_paths(input.test_paths) .. [[}
local mode = ]] .. quote(input.mode) .. [[

local function mount_bundled_library()
	local segments = string.split(library_require_path, ".")
	if #segments < 2 then
		error("Lutest library require path must start with a Roblox service and end with a ModuleScript name.")
	end

	local parent = game:GetService(segments[1])
	for index = 2, #segments - 1 do
		local child = parent:FindFirstChild(segments[index])
		if child == nil then
			child = Instance.new("Folder")
			child.Name = segments[index]
			child.Parent = parent
		end
		parent = child
	end

	local library = bundle_root:FindFirstChild("__lutest_lib")
	if library == nil then
		error("Lutest library was not present in the deserialized bundle.")
	end
	local entry = library:FindFirstChild("lib")
	if entry == nil then
		error("Lutest library entry module was not present in the deserialized bundle.")
	end
	local context = library:FindFirstChild("context")
	if context == nil then
		error("Lutest library runtime context was not present in the deserialized bundle.")
	end
	entry.Name = segments[#segments]
	for _, child in library:GetChildren() do
		local existing = parent:FindFirstChild(child.Name)
		if existing ~= nil then
			existing:Destroy()
		end
		child.Parent = parent
	end
	return context
end

local context_module = mount_bundled_library()
local runtime_context = require(context_module)
local test_api = require(]] .. input.require_path .. [[)
local core_folder = context_module.Parent:FindFirstChild("core")
if core_folder == nil then
	error("Lutest core runtime was not present in the deserialized bundle.")
end
local executor_module = core_folder:FindFirstChild("executor")
if executor_module == nil then
	error("Lutest suite executor was not present in the deserialized bundle.")
end
local test_executor = require(executor_module)

local function find_module(relative_path)
	local current = bundle_root
	for segment in string.gmatch(relative_path, "[^/]+") do
		segment = string.gsub(segment, "%.luau$", "")
		current = current:FindFirstChild(segment)
		if current == nil then
			return nil
		end
	end
	return current
end

local function run_suite(name, tests)
	if mode == "test" then
		return test_executor.run({ name = name, tests = tests })
	end

	local results = {}
	local counts = { passed = 0, failed = 0, skipped = 0, todo = 0 }
	for _, test in tests do
		local result = if test.mode == "todo"
			then { name = test.name, kind = "todo" }
			else { name = test.name, kind = "skipped" }
		table.insert(results, result)
		counts[result.kind] += 1
	end

	return {
		name = name,
		total_tests = #tests,
		passed_tests = counts.passed,
		failed_tests = counts.failed,
		skipped_tests = counts.skipped,
		todo_tests = counts.todo,
		results = results,
		lifecycle_failures = {},
	}
end

local output = { version = 1, results = {}, load_failures = {} }
for _, test_path in test_paths do
	local module = find_module(test_path)
	if module == nil then
		table.insert(output.load_failures, {
			path = test_path,
			error_message = "Test module was not present in the deserialized bundle.",
		})
		continue
	end
	if not module:IsA("ModuleScript") then
		table.insert(output.load_failures, {
			path = test_path,
			error_message = "Roblox remote test suites must be ModuleScripts. LocalScripts and Scripts cannot run in a Luau execution session. Move the testable logic into a ModuleScript and keep the LocalScript or Script as an integration layer.",
		})
		continue
	end

	local tests = {}
	runtime_context.set_register(function(spec)
		table.insert(tests, spec)
	end)
	local ok, loaded = xpcall(function()
		return require(module)
	end, debug.traceback)
	runtime_context.set_register(nil)
	if not ok then
		table.insert(output.load_failures, {
			path = test_path,
			error_message = tostring(loaded),
		})
		continue
	end
	if
		type(loaded) == "table"
		and loaded.__lutest_suite_load_result == true
		and loaded.ok == false
	then
		table.insert(output.load_failures, {
			path = test_path,
			error_message = tostring(loaded.value),
		})
		continue
	end
	local suite_result = run_suite(test_path, tests) :: any
	if #tests == 0 then
		suite_result.warnings = {
			test_path .. " was discovered as a test suite but registered no tests.",
		}
	end
	table.insert(output.results, suite_result)
end

print("LUTEST_RESULT_V1:" .. HttpService:JSONEncode(output))
]]
end

t.test('should generate a harness that emits one versioned envelope', function()
	const source = generate {
		require_path = 'game.ReplicatedStorage.Packages.lutest',
		test_paths = { 'tests/example.luau' },
		mode = 'test',
	}
	assert(source:find('LUTEST_RESULT_V1:', 1, true) ~= nil)
	assert(
		source:find('game.ReplicatedStorage.Packages.lutest', 1, true)
			~= nil
	)
	assert(source:find('tests/example.luau', 1, true) ~= nil)
	assert(source:find('entry.Name = segments[#segments]', 1, true) ~= nil)
	assert(source:find('existing:Destroy()', 1, true) ~= nil)
	assert(source:find('runtime_context.set_register', 1, true) ~= nil)
	assert(source:find('suite executor', 1, true) ~= nil)
	assert(source:find('__lutest_suite_load_result', 1, true) ~= nil)
	assert(source:find('loaded.value', 1, true) ~= nil)
	assert(source:find('test_api.set_runtime_register', 1, true) == nil)
	assert(source:find('must be ModuleScripts', 1, true) ~= nil)
end)

return {
	generate = generate,
}
