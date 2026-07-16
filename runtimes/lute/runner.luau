const core = require '@core'
const errors = require '@core/errors'
const context = require '@lib/context'
const registry = require '@lib/registry'
const config = require '@runtimes/lute/config'
const discovery = require '@runtimes/lute/discovery'
const t = require '@lutest_release'
const path_utils = require '@lutest/utils/path'
const fs = require '@std/fs'
const luau = require '@std/luau'
const path = require '@std/path'

export type TestSpec = core.TestSpec
export type TestSuite = core.TestSuite
export type TestSuiteResult = core.TestSuiteResult
type LutestConfig = config.LutestConfig
type ReleaseApi = typeof(t)
type ModuleCache = { [string]: unknown }
type LoadingMap = { [string]: boolean }
type ExecutionState = {
	current_module: string?,
}

const SELF_REQUIRE_PREFIX = '@self/'

const function wrap_module_source(source: string): string
	return [[
local __lutest_require, __lutest_register = ...
local require = __lutest_require
]] .. source
end

const function resolve_self_require_path(
	require_path: string,
	module_path: string
): string?
	if require_path:sub(1, #SELF_REQUIRE_PREFIX) ~= SELF_REQUIRE_PREFIX then
		return nil
	end

	const relative_path = require_path:sub(#SELF_REQUIRE_PREFIX + 1)
	if relative_path == '' then return nil end

	return path_utils.normalize_path(
		path.join(path.dirname(module_path), `{relative_path}.luau`)
	)
end

const function is_project_module(
	resolved_path: string,
	project_root: string
): boolean
	if resolved_path == project_root then return true end
	return resolved_path:sub(1, #project_root + 1) == `{project_root}/`
end

const function format_load_error(module_path: string, err: unknown): string
	return errors.runtime_error('Test file could not load', {
		where = path_utils.relative_to_cwd(module_path),
		how_to_fix = 'Fix the error in this test file and run again.',
		details = debug.traceback(tostring(err), 2),
	})
end

const function should_use_embedded_release_api(
	require_path: string,
	project_config: LutestConfig
): boolean
	if require_path ~= project_config.require then return false end

	return string.sub(require_path, 1, 1) == '@'
end

const function create_embedded_release_api(): ReleaseApi
	local active_scope = nil :: core.TestScope?

	const function is_collecting(): boolean
		return context.get_register() ~= nil or registry.is_active()
	end

	const function scope_or_error(): core.TestScope
		const scope = active_scope
		if scope ~= nil then return scope end

		error('Hooks can only be registered inside t.suite().', 2)
	end

	const function register_spec(spec: TestSpec)
		if not is_collecting() then return end
		if context.register(spec) then return end

		registry.register(spec)
	end

	const function test(name: string, fn: () -> ()): TestSpec
		const spec = {
			name = name,
			mode = 'run',
			fn = fn,
			scope = active_scope,
		} :: TestSpec

		register_spec(spec)
		return spec
	end

	const function skip(name: string, fn: () -> ()): TestSpec
		const spec = {
			name = name,
			mode = 'skip',
			fn = fn,
			scope = active_scope,
		} :: TestSpec

		register_spec(spec)
		return spec
	end

	const function only(name: string, fn: () -> ()): TestSpec
		const spec = {
			name = name,
			mode = 'only',
			fn = fn,
			scope = active_scope,
		} :: TestSpec

		register_spec(spec)
		return spec
	end

	const function todo(name: string): TestSpec
		const spec = {
			name = name,
			mode = 'todo',
			scope = active_scope,
		} :: TestSpec

		register_spec(spec)
		return spec
	end

	const function suite(name: string, register: () -> ())
		if not is_collecting() then return end
		if active_scope ~= nil then
			error('Nested t.suite() calls are not supported.', 2)
		end

		const scope = {
			name = name,
			hooks = {
				before_all = {},
				before_each = {},
				after_each = {},
				after_all = {},
			},
		} :: core.TestScope

		active_scope = scope
		const ok, result = (pcall :: any)(register)
		active_scope = nil
		if not ok then error(result, 0) end
	end

	const function before_all(hook: core.HookFn)
		if not is_collecting() then return end
		table.insert(scope_or_error().hooks.before_all, hook)
	end

	const function before_each(hook: core.HookFn)
		if not is_collecting() then return end
		table.insert(scope_or_error().hooks.before_each, hook)
	end

	const function after_each(hook: core.HookFn)
		if not is_collecting() then return end
		table.insert(scope_or_error().hooks.after_each, hook)
	end

	const function after_all(hook: core.HookFn)
		if not is_collecting() then return end
		table.insert(scope_or_error().hooks.after_all, hook)
	end

	return {
		test = test,
		skip = skip,
		only = only,
		todo = todo,
		suite = suite,
		before_all = before_all,
		before_each = before_each,
		after_each = after_each,
		after_all = after_all,
	}
end

const embedded_release_api: ReleaseApi = create_embedded_release_api()

const function create_runtime_register(
	tests: { TestSpec },
	execution_state: ExecutionState,
	suite_module_path: string
): (TestSpec) -> ()
	return function(test: TestSpec)
		if execution_state.current_module ~= suite_module_path then
			return
		end

		table.insert(tests, test)
	end
end

const function execute_module(
	module_path: string,
	suite_module_path: string,
	tests: { TestSpec },
	module_cache: ModuleCache,
	loading_modules: LoadingMap,
	execution_state: ExecutionState,
	project_config: LutestConfig
): unknown
	if module_cache[module_path] ~= nil then
		return module_cache[module_path]
	end
	if loading_modules[module_path] then
		error(
			`cyclic require detected while loading '{module_path}'`,
			0
		)
	end

	loading_modules[module_path] = true

	const project_root = path_utils.cwd()
	const runtime_register = create_runtime_register(
		tests,
		execution_state,
		suite_module_path
	)
	const runtime_require = function(require_path: string): unknown
		if
			should_use_embedded_release_api(
				require_path,
				project_config
			)
		then
			return embedded_release_api
		end
		const self_path =
			resolve_self_require_path(require_path, module_path)
		if self_path ~= nil then
			return execute_module(
				self_path,
				suite_module_path,
				tests,
				module_cache,
				loading_modules,
				execution_state,
				project_config
			)
		end

		const resolved_ok, resolved_result = pcall(function()
			return path_utils.normalize_path(
				path.format(
					luau.resolveModule(
						require_path,
						module_path
					)
				)
			)
		end)
		if not resolved_ok then return (require)(require_path) end

		const resolved_path = resolved_result :: string
		if not is_project_module(resolved_path, project_root) then
			return (require)(require_path)
		end

		return execute_module(
			resolved_path,
			suite_module_path,
			tests,
			module_cache,
			loading_modules,
			execution_state,
			project_config
		)
	end

	const ok, result = xpcall(function()
		const previous_module = execution_state.current_module
		execution_state.current_module = module_path
		const source = fs.readFileToString(module_path)
		const chunk = luau.load(
			luau.compile(wrap_module_source(source)),
			module_path
		)
		const chunk_result = chunk(runtime_require, runtime_register)
		execution_state.current_module = previous_module
		return chunk_result
	end, function(err)
		return err
	end)

	if execution_state.current_module == module_path then
		execution_state.current_module = nil
	end

	loading_modules[module_path] = nil
	if not ok then error(result, 0) end

	module_cache[module_path] = result
	return result
end

const function load_module(
	module_path: string,
	project_config: LutestConfig
): (unknown, { TestSpec })
	const tests = {} :: { TestSpec }
	const module_cache = {} :: ModuleCache
	const loading_modules = {} :: LoadingMap
	const execution_state = {
		current_module = nil,
	} :: ExecutionState
	const previous_register = context.get_register()

	context.set_register(
		create_runtime_register(tests, execution_state, module_path)
	)

	const ok, result = xpcall(function()
		return execute_module(
			module_path,
			module_path,
			tests,
			module_cache,
			loading_modules,
			execution_state,
			project_config
		)
	end, function(err)
		return format_load_error(module_path, err)
	end)

	context.set_register(previous_register)
	if not ok then error(result, 0) end

	return result, tests
end

const function create_suite(module_path: string, tests: { TestSpec }): TestSuite
	local warnings = nil :: { string }?
	if #tests == 0 then
		warnings = {
			`{path_utils.relative_to_cwd(module_path)} was discovered as a test suite but registered no tests.`,
		}
	end

	return {
		name = path_utils.relative_to_cwd(module_path),
		tests = tests,
		warnings = warnings,
	}
end

const function collect_suites(
	paths: { string },
	config_path: string?
): { TestSuite }
	const project_config = config.load_config(config_path)
	const suites = {} :: { TestSuite }

	for _, module_path in paths do
		const resolved_module_path =
			path_utils.resolve_from_cwd(module_path)
		const _, tests =
			load_module(resolved_module_path, project_config)
		table.insert(suites, create_suite(resolved_module_path, tests))
	end

	return suites
end

const function has_only_tests(suites: { TestSuite }): boolean
	for _, suite in suites do
		for _, test in suite.tests do
			if test.mode == 'only' then return true end
		end
	end

	return false
end

const function run_file(
	module_path: string,
	config_path: string?
): { TestSuiteResult }
	const project_config = config.load_config(config_path)
	const resolved_module_path = path_utils.resolve_from_cwd(module_path)
	const _, tests = load_module(resolved_module_path, project_config)
	return { core.run(create_suite(resolved_module_path, tests)) }
end

const function run_files(
	paths: { string },
	config_path: string?
): { TestSuiteResult }
	const suites = collect_suites(paths, config_path)
	const suite_results = {} :: { TestSuiteResult }
	const resolved_focus_only = has_only_tests(suites)

	for _, suite in suites do
		table.insert(
			suite_results,
			core.run(suite, {
				focus_only = resolved_focus_only,
			})
		)
	end

	return suite_results
end

const function run_discovered(
	paths: { string },
	config_path: string?
): { TestSuiteResult }
	return run_files(
		discovery.discover_files(paths, config_path),
		config_path
	)
end

t.test('should not register tests from required dependencies', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'runner-dependency-tests')
	const suite_path =
		path_utils.normalize_path(path.join(temp_cwd, 'suite.luau'))
	const test_lib_path = path_utils.normalize_path(
		path.join(temp_cwd, 'custom-test-lib.luau')
	)
	const dependency_path = path_utils.normalize_path(
		path.join(temp_cwd, 'dependency.luau')
	)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		test_lib_path,
		[[
local function test(name, fn)
	__lutest_register({
		name = name,
		mode = "run",
		fn = fn,
	})
end

return {
	test = test,
}
]]
	)
	fs.writeStringToFile(
		dependency_path,
		[[
local t = require("./custom-test-lib")

t.test("dependency test", function()
	error("dependency test should not run")
end)

return {
	value = 41,
}
]]
	)
	fs.writeStringToFile(
		suite_path,
		[[
local dependency = require("./dependency")
local t = require("./custom-test-lib")

t.test("suite test", function()
	assert(dependency.value == 41)
end)

return dependency
]]
	)

	const _, tests = load_module(suite_path, {
		roots = { '.' },
		ignore = {},
		require = './custom-test-lib',
		gitignore = true,
	})

	assert(#tests == 1)
	assert(tests[1].name == 'suite test')

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should keep the embedded API inert outside collection', function()
	const previous_hook = context.get_register()
	const api = create_embedded_release_api()
	local suite_called = false

	context.clear_register()
	registry.clear()

	api.test('run test', function() end)
	api.skip('skip test', function() end)
	api.only('only test', function() end)
	api.todo 'todo test'
	api.before_all(function() end)
	api.before_each(function() end)
	api.after_each(function() end)
	api.after_all(function() end)
	api.suite('ignored suite', function()
		suite_called = true
	end)

	const specs = registry.collect 'inactive-module'
	context.set_register(previous_hook)
	registry.clear()

	assert(suite_called == false)
	assert(#specs == 0)
end)

t.test('should respect the configured test lib require path', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'runner-custom-test-lib')
	const suite_path =
		path_utils.normalize_path(path.join(temp_cwd, 'suite.luau'))
	const test_lib_path = path_utils.normalize_path(
		path.join(temp_cwd, 'custom-test-lib.luau')
	)

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		test_lib_path,
		[[
local function test(name, fn)
	__lutest_register({
		name = name,
		mode = "run",
		fn = fn,
	})
end

return {
	version = "custom",
	test = test,
}
]]
	)
	fs.writeStringToFile(
		suite_path,
		[[
local t = require("./custom-test-lib")

t.test("suite test", function()
	assert(t.version == "custom")
end)

return t.version
]]
	)

	const result, tests = load_module(suite_path, {
		roots = { '.' },
		ignore = {},
		require = './custom-test-lib',
		gitignore = true,
	})

	assert(result == 'custom')
	assert(#tests == 1)
	assert(tests[1].name == 'suite test')

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should resolve self imports relative to the current module', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'runner-self-import')
	const suite_path =
		path_utils.normalize_path(path.join(temp_cwd, 'suite.luau'))
	const helper_path =
		path_utils.normalize_path(path.join(temp_cwd, 'helper.luau'))

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(helper_path, 'return { value = 42 }')
	fs.writeStringToFile(
		suite_path,
		[[
local helper = require '@self/helper'
local t = require '@lutest_release'

t.test('suite test', function()
	assert(helper.value == 42)
end)
]]
	)

	const _, tests = load_module(suite_path, {
		roots = { '.' },
		ignore = {},
		require = '@lutest_release',
		gitignore = true,
	})

	assert(#tests == 1)
	assert(tests[1].name == 'suite test')

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test(
	'should provide the configured require path through the release api',
	function()
		const temp_root = path_utils.resolve_path(
			path_utils.cwd(),
			'dist/test-tmp'
		)
		const temp_cwd = path_utils.resolve_path(
			temp_root,
			'runner-release-test-lib'
		)
		const suite_path = path_utils.normalize_path(
			path.join(temp_cwd, 'suite.luau')
		)

		if fs.exists(temp_cwd) then
			fs.removeDirectory(temp_cwd, { recursive = true })
		end

		fs.createDirectory(temp_cwd, { makeParents = true })
		fs.writeStringToFile(
			suite_path,
			[[
local t = require("@lutest_release")

t.test("suite test", function()
	assert(true)
end)

return t
]]
		)

		const result, tests = load_module(suite_path, {
			roots = { '.' },
			ignore = {},
			require = '@lutest_release',
			gitignore = true,
		})

		assert(type(result) == 'table')
		assert(#tests == 1)
		assert(tests[1].name == 'suite test')

		fs.removeDirectory(temp_cwd, { recursive = true })
	end
)

t.test('should keep the standard runtime environment available', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'runner-runtime-env')
	const suite_path =
		path_utils.normalize_path(path.join(temp_cwd, 'suite.luau'))

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		suite_path,
		[[
return {
	assert_type = type(assert),
	math_type = type(math),
	string_type = type(string),
	table_type = type(table),
}
]]
	)

	const result, tests = load_module(suite_path, {
		roots = { '.' },
		ignore = {},
		require = '@lutest_release',
		gitignore = true,
	})

	assert(type(result) == 'table')
	assert((result :: any).assert_type == 'function')
	assert((result :: any).math_type == 'table')
	assert((result :: any).string_type == 'table')
	assert((result :: any).table_type == 'table')
	assert(#tests == 0)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should warn when a discovered suite registers no tests', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd =
		path_utils.resolve_path(temp_root, 'runner-empty-suite')
	const suite_path =
		path_utils.normalize_path(path.join(temp_cwd, 'suite.luau'))

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(suite_path, 'return {}')

	const results = run_file(suite_path)
	assert(#results == 1)
	assert(results[1].warnings ~= nil)
	assert(
		(results[1].warnings :: { string })[1]
			== 'dist/test-tmp/runner-empty-suite/suite.luau was discovered as a test suite but registered no tests.'
	)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

t.test('should report runtime load errors with test file context', function()
	const temp_root =
		path_utils.resolve_path(path_utils.cwd(), 'dist/test-tmp')
	const temp_cwd = path_utils.resolve_path(temp_root, 'runner-load-error')
	const suite_path =
		path_utils.normalize_path(path.join(temp_cwd, 'suite.luau'))

	if fs.exists(temp_cwd) then
		fs.removeDirectory(temp_cwd, { recursive = true })
	end

	fs.createDirectory(temp_cwd, { makeParents = true })
	fs.writeStringToFile(
		suite_path,
		[[
error("boom from module")
]]
	)

	local message = nil :: string?
	const ok = xpcall(function()
		load_module(suite_path, {
			roots = { '.' },
			ignore = {},
			require = '@lutest_release',
			gitignore = true,
		})
	end, function(err)
		message = tostring(err)
		return message
	end)

	assert(ok == false)
	assert(message ~= nil)
	message = errors.strip_ansi(errors.display_error(message))
	assert(message:find('RuntimeError:', 1, true) == nil)
	assert(message:find('Test file could not load', 1, true) ~= nil)
	assert(message:find('> Details', 1, true) ~= nil)
	assert(message:find('boom from module', 1, true) ~= nil)

	fs.removeDirectory(temp_cwd, { recursive = true })
end)

return {
	collect_suites = collect_suites,
	run_file = run_file,
	run_files = run_files,
	run_discovered = run_discovered,
}
