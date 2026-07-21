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
	if entry == nil then entry = library:FindFirstChild("init") end
	if entry == nil then
		error("Lutest library entry module was not present in the deserialized bundle.")
	end
	local context = library:FindFirstChild("context")
	if context == nil then context = entry:FindFirstChild("context") end
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

local function mount_project_children(source, parent)
	for _, child in source:GetChildren() do
		if child.Name == "__lutest_lib" then
			continue
		end
		local existing = parent:FindFirstChild(child.Name)
		if existing == nil then
			child.Parent = parent
			continue
		end
		if child:IsA("Folder") then
			mount_project_children(child, existing)
			child:Destroy()
			continue
		end
		existing:Destroy()
		child.Parent = parent
	end
end

mount_project_children(bundle_root, game)
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
	local current = game
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
local prepared_suites = {}
local prepared_by_module = {}

local function append_load_failure(path, error_message)
	table.insert(output.load_failures, {
		path = path,
		error_message = error_message,
	})
end

for _, test_path in test_paths do
	local module = find_module(test_path)
	if module == nil then
		append_load_failure(test_path, "Test module was not present in the deserialized bundle.")
		continue
	end
	if not module:IsA("ModuleScript") then
		append_load_failure(test_path, "Roblox remote test suites must be ModuleScripts. LocalScripts and Scripts cannot run in a Luau execution session. Move the testable logic into a ModuleScript and keep the LocalScript or Script as an integration layer.")
		continue
	end

	local runner_module = module:FindFirstChild("__lutest_suite_runner")
	if runner_module == nil then
		append_load_failure(test_path, "Test module did not expose a Lutest suite runner.")
		continue
	end
	local runner_ok, runner = xpcall(function()
		return require(runner_module)
	end, debug.traceback)
	if not runner_ok or type(runner) ~= "table" or type(runner.configure) ~= "function" then
		append_load_failure(test_path, "Test module did not expose a valid Lutest suite runner.")
		continue
	end
	local prepared = {
		path = test_path,
		module = module,
		runner = runner,
		tests = {},
	}
	runner.configure(runtime_context, module)
	table.insert(prepared_suites, prepared)
	prepared_by_module[module] = prepared
end

runtime_context.begin_session()
runtime_context.set_register(function(spec)
	local owner = runtime_context.get_registration_owner()
	if owner == nil then return end

	local prepared = prepared_by_module[owner]
	if prepared == nil then return end

	table.insert(prepared.tests, spec)
end)

for _, prepared in prepared_suites do
	local ok, loaded = xpcall(function()
		return require(prepared.module)
	end, debug.traceback)
	if not ok then
		append_load_failure(prepared.path, tostring(loaded))
		continue
	end
	if type(loaded) == "table" and loaded.__lutest_suite_load_failure == true then
		append_load_failure(prepared.path, tostring(loaded.error_message))
		continue
	end
	prepared.loaded = true
end

runtime_context.set_register(nil)
runtime_context.end_session()

for _, prepared in prepared_suites do
	if not prepared.loaded then continue end

	local suite_result = run_suite(prepared.path, prepared.tests) :: any
	if #prepared.tests == 0 then
		suite_result.warnings = {
			prepared.path .. " was discovered as a test suite but registered no tests.",
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
	const project_mount = source:find(
		'mount_project_children(bundle_root, game)',
		1,
		true
	)
	const library_mount = source:find(
		'local context_module = mount_bundled_library()',
		1,
		true
	)
	assert(project_mount ~= nil)
	assert(library_mount ~= nil)
	assert(project_mount < library_mount)
	assert(source:find('tests/example.luau', 1, true) ~= nil)
	assert(source:find('entry.Name = segments[#segments]', 1, true) ~= nil)
	assert(
		source:find(
			'mount_project_children(bundle_root, game)',
			1,
			true
		) ~= nil
	)
	assert(source:find('library:FindFirstChild("init")', 1, true) ~= nil)
	assert(source:find('entry:FindFirstChild("context")', 1, true) ~= nil)
	assert(source:find('existing:Destroy()', 1, true) ~= nil)
	assert(source:find('runtime_context.set_register', 1, true) ~= nil)
	assert(source:find('local prepared_suites = {}', 1, true) ~= nil)
	assert(
		source:find(
			'runner.configure(runtime_context, module)',
			1,
			true
		) ~= nil
	)
	assert(source:find('prepared_by_module[owner]', 1, true) ~= nil)
	assert(source:find('__lutest_suite_runner', 1, true) ~= nil)
	assert(source:find('suite executor', 1, true) ~= nil)
	assert(source:find('__lutest_suite_load_failure', 1, true) ~= nil)
	assert(source:find('loaded.error_message', 1, true) ~= nil)
	assert(source:find('test_api.set_runtime_register', 1, true) == nil)
	assert(source:find('must be ModuleScripts', 1, true) ~= nil)
end)

return {
	generate = generate,
}
