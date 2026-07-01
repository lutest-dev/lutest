const core = require '@core'
const discovery = require '@runtimes/lute/discovery'
const fs = require '@std/fs'
const luau = require '@std/luau'
const path = require '@std/path'
const process = require '@std/process'

export type TestSpec = core.TestSpec
export type TestSuite = core.TestSuite
export type TestSuiteResult = core.TestSuiteResult
type ModuleCache = { [string]: unknown }
type LoadingMap = { [string]: boolean }

const function normalize_path(value: path.Pathlike): string
	const formatted = path.format(path.normalize(value))
	return (formatted:gsub('\\', '/'))
end

const function resolve_module_path(module_path: string): string
	const cwd = normalize_path(process.cwd())
	const resolved = if path.isAbsolute(module_path)
		then module_path
		else path.join(cwd, module_path)

	return normalize_path(resolved)
end

const function suite_name_from_module_path(module_path: string): string
	const cwd = normalize_path(process.cwd())
	return normalize_path(path.relative(cwd, module_path))
end

const function is_project_module(
	resolved_path: string,
	project_root: string
): boolean
	if resolved_path == project_root then return true end
	return resolved_path:sub(1, #project_root + 1) == `{project_root}/`
end

const function format_load_error(module_path: string, err: unknown): string
	const message = `failed to load '{module_path}': {tostring(err)}`
	return debug.traceback(message, 2)
end

const function execute_module(
	module_path: string,
	tests: { TestSpec },
	module_cache: ModuleCache,
	loading_modules: LoadingMap
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

	const env = table.clone(_G :: any)
	const project_root = normalize_path(process.cwd())
	env.__lutest_register = function(test: TestSpec)
		table.insert(tests, test)
	end
	env.require = function(require_path: string)
		const resolved_path = normalize_path(
			path.format(
				luau.resolveModule(require_path, module_path)
			)
		)
		if not is_project_module(resolved_path, project_root) then
			return (require)(require_path)
		end

		return execute_module(
			resolved_path,
			tests,
			module_cache,
			loading_modules
		)
	end

	const ok, result = xpcall(function()
		const source = fs.readFileToString(module_path)
		const chunk = luau.load(luau.compile(source), module_path, env)
		return chunk()
	end, function(err)
		return err
	end)

	loading_modules[module_path] = nil
	if not ok then error(result, 0) end

	module_cache[module_path] = result
	return result
end

const function load_module(module_path: string): (unknown, { TestSpec })
	const tests = {} :: { TestSpec }
	const module_cache = {} :: ModuleCache
	const loading_modules = {} :: LoadingMap

	const ok, result = xpcall(function()
		return execute_module(
			module_path,
			tests,
			module_cache,
			loading_modules
		)
	end, function(err)
		return format_load_error(module_path, err)
	end)

	if not ok then error(result, 0) end

	return result, tests
end

const function warn_missing_tests(module_path: string)
	print(
		`warning: module '{suite_name_from_module_path(module_path)}' depends on @lib but registered no tests`
	)
end

const function create_suite(module_path: string, tests: { TestSpec }): TestSuite
	return {
		name = suite_name_from_module_path(module_path),
		tests = tests,
	}
end

const function has_only_tests(suites: { TestSuite }): boolean
	for _, suite in suites do
		for _, test in suite.tests do
			if test.mode == 'only' then return true end
		end
	end

	return false
end

const function run_file(module_path: string): { TestSuiteResult }
	const resolved_module_path = resolve_module_path(module_path)
	const _, tests = load_module(resolved_module_path)
	if #tests == 0 then
		warn_missing_tests(resolved_module_path)
		return {}
	end

	return { core.run(create_suite(resolved_module_path, tests)) }
end

const function run_files(paths: { string }): { TestSuiteResult }
	const suites = {} :: { TestSuite }
	const focus_only = false

	for _, module_path in paths do
		const resolved_module_path = resolve_module_path(module_path)
		const _, tests = load_module(resolved_module_path)
		if #tests == 0 then
			warn_missing_tests(resolved_module_path)
			continue
		end

		table.insert(suites, create_suite(resolved_module_path, tests))
	end

	const suite_results = {} :: { TestSuiteResult }
	const resolved_focus_only = has_only_tests(suites)

	for _, suite in suites do
		table.insert(
			suite_results,
			core.run(suite, {
				focus_only = resolved_focus_only or focus_only,
			})
		)
	end

	return suite_results
end

const function run_discovered(paths: { string }): { TestSuiteResult }
	return run_files(discovery.discover_files(paths))
end

return {
	run_file = run_file,
	run_files = run_files,
	run_discovered = run_discovered,
}
