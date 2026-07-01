const core = require '@core'
const discovery = require '@runtimes/lute/discovery'
const luau = require '@std/luau'
const path = require '@std/path'
const process = require '@std/process'
const registry = require '@lib/registry'

export type TestSpec = core.TestSpec
export type TestSuite = core.TestSuite
export type TestSuiteResult = core.TestSuiteResult

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

const function format_load_error(module_path: string, err: unknown): string
	const message = `failed to load '{module_path}': {tostring(err)}`
	return debug.traceback(message, 2)
end

const function load_module(module_path: string): (unknown, { TestSpec })
	registry.begin()

	const ok, result = xpcall(function()
		return luau.loadModule(module_path)
	end, function(err)
		return format_load_error(module_path, err)
	end)

	const tests = registry.collect(module_path)
	registry.clear()

	if not ok then error(result, 0) end

	return result, tests
end

const function warn_missing_tests(module_path: string)
	warn(
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
