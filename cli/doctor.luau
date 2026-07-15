const fs = require '@std/fs'
const config = require '@runtimes/lute/config'
const bundle = require '@runtimes/roblox/bundle'
const credentials = require '@runtimes/roblox/credentials'
const path_utils = require '@lutest/utils/path'
const ui = require '@lutest/utils/ui'
const t = require '@lutest_release'

type ProjectConfig = config.ProjectConfig
type LutestConfig = config.LutestConfig
type RobloxConfig = config.RobloxConfig

export type DoctorReport = {
	ready: boolean,
	output: string,
}

type DoctorOptions = {
	config_path: string?,
	config_exists: boolean,
	has_api_key: boolean,
	bundle_available: boolean,
	root_exists: ((root: string) -> boolean)?,
}

const function has_discovery_config(runtime: LutestConfig?): boolean
	return runtime ~= nil and runtime.require ~= '' and #runtime.roots > 0
end

const function is_glob_root(root: string): boolean
	return root:find('*', 1, true) ~= nil
		or root:find('?', 1, true) ~= nil
		or root:find('[', 1, true) ~= nil
end

const function unavailable_literal_roots(
	runtime: LutestConfig,
	root_exists: (root: string) -> boolean
): { string }
	const unavailable = {} :: { string }
	for _, root in runtime.roots do
		if is_glob_root(root) or root_exists(root) then continue end
		table.insert(unavailable, root)
	end
	return unavailable
end

const function append_unavailable_roots(
	lines: { string },
	runtime_name: string,
	roots: { string }
): boolean
	if #roots == 0 then return true end

	table.insert(lines, ui.failed(`{runtime_name} runtime not ready`))
	for _, root in roots do
		table.insert(lines, `  unavailable root: {root}`)
	end
	table.insert(lines, '')
	table.insert(
		lines,
		ui.warned 'Create the directory or update discovery.roots in lutest.toml.'
	)
	return false
end

const function has_roblox_config(project: ProjectConfig): boolean
	const options = project.roblox_options
	return has_discovery_config(project.roblox)
		and options ~= nil
		and (options :: RobloxConfig).universe_id > 0
		and (options :: RobloxConfig).place_id > 0
end

const function append_configuration(lines: { string }, options: DoctorOptions)
	if options.config_exists then
		table.insert(lines, ui.passed 'Configuration loaded')
		table.insert(lines, `  {options.config_path or 'lutest.toml'}`)
		return
	end

	table.insert(lines, ui.passed 'Default configuration loaded')
	table.insert(lines, '  No lutest.toml found; using Lute defaults.')
end

const function append_lute_runtime(
	lines: { string },
	project: ProjectConfig,
	root_exists: (root: string) -> boolean
): boolean
	if project.lute == nil then return true end
	if not has_discovery_config(project.lute) then
		table.insert(lines, '')
		table.insert(lines, ui.failed 'Lute runtime not ready')
		table.insert(lines, '  require or roots: missing')
		table.insert(lines, '')
		table.insert(
			lines,
			ui.warned 'Set require and roots in [discovery.lute].'
		)
		return false
	end

	const runtime = project.lute :: LutestConfig
	table.insert(lines, '')
	if
		not append_unavailable_roots(
			lines,
			'Lute',
			unavailable_literal_roots(runtime, root_exists)
		)
	then
		return false
	end
	table.insert(lines, '')
	table.insert(lines, ui.passed 'Lute runtime ready')
	table.insert(lines, `  roots: {table.concat(runtime.roots, ', ')}`)
	return true
end

const function append_roblox_runtime(
	lines: { string },
	project: ProjectConfig,
	options: DoctorOptions,
	root_exists: (root: string) -> boolean
): boolean
	if project.roblox == nil and project.roblox_options == nil then
		return true
	end

	table.insert(lines, '')
	if not has_roblox_config(project) then
		table.insert(lines, ui.failed 'Roblox runtime not ready')
		table.insert(lines, '  configuration: incomplete')
		table.insert(lines, '')
		table.insert(
			lines,
			ui.warned(
				'Set require and roots in [discovery.roblox], and '
					.. 'universe_id and place_id in [roblox].'
			)
		)
		return false
	end

	const runtime = project.roblox :: LutestConfig
	const roblox = project.roblox_options :: RobloxConfig
	if
		not append_unavailable_roots(
			lines,
			'Roblox',
			unavailable_literal_roots(runtime, root_exists)
		)
	then
		return false
	end
	if not options.has_api_key then
		table.insert(lines, ui.failed 'Roblox runtime not ready')
		table.insert(lines, '  API key: missing')
		table.insert(lines, '')
		table.insert(
			lines,
			ui.warned 'Add ROBLOX_OPEN_CLOUD_API_KEY to .env or your environment.'
		)
		return false
	end
	if not options.bundle_available then
		table.insert(lines, ui.failed 'Roblox runtime not ready')
		table.insert(
			lines,
			'  Lutest could not prepare the Roblox bundle.'
		)
		table.insert(lines, '')
		table.insert(
			lines,
			ui.warned 'Reinstall Lutest or report this output as an issue.'
		)
		return false
	end

	table.insert(lines, ui.passed 'Roblox runtime ready')
	table.insert(lines, `  roots: {table.concat(runtime.roots, ', ')}`)
	table.insert(lines, '  API key: available')
	table.insert(lines, `  place: {roblox.place_id}`)
	return true
end

const function inspect(
	project: ProjectConfig,
	options: DoctorOptions
): DoctorReport
	local lines = {} :: { string }
	append_configuration(lines, options)
	const root_exists = options.root_exists
		or function(root)
			return fs.exists(path_utils.resolve_from_cwd(root))
		end

	const lute_ready = append_lute_runtime(lines, project, root_exists)
	const roblox_ready =
		append_roblox_runtime(lines, project, options, root_exists)
	const ready = lute_ready and roblox_ready

	return {
		ready = ready,
		output = table.concat(lines, '\n'),
	}
end

const function run(config_path: string?): DoctorReport
	const project = config.load_project_config(config_path)
	const config_exists = config_path ~= nil
		or fs.exists(path_utils.resolve_from_cwd 'lutest.toml')
	const bundle_available = if has_roblox_config(project)
		then bundle.is_available()
		else true

	return inspect(project, {
		config_path = config_path,
		config_exists = config_exists,
		has_api_key = credentials.find() ~= nil,
		bundle_available = bundle_available,
	})
end

t.test('should report configured runtimes as ready', function()
	const report = inspect({
		lute = {
			roots = { 'src' },
			ignore = {},
			require = '@lutest_release',
			gitignore = true,
		},
		roblox = {
			roots = { 'game' },
			ignore = {},
			require = 'ReplicatedStorage.Packages.lutest',
			gitignore = true,
		},
		roblox_options = {
			universe_id = 1,
			place_id = 2,
			poll_interval_seconds = 2,
			timeout_seconds = 300,
		},
	}, {
		config_exists = true,
		has_api_key = true,
		bundle_available = true,
		root_exists = function()
			return true
		end,
	})

	assert(report.ready == true)
	assert(report.output:find('Roblox runtime ready', 1, true) ~= nil)
	assert(report.output:find('API key: available', 1, true) ~= nil)
end)

t.test(
	'should report a missing Roblox API key without exposing values',
	function()
		const report = inspect({
			lute = nil,
			roblox = {
				roots = { 'game' },
				ignore = {},
				require = 'ReplicatedStorage.Packages.lutest',
				gitignore = true,
			},
			roblox_options = {
				universe_id = 1,
				place_id = 2,
				poll_interval_seconds = 2,
				timeout_seconds = 300,
			},
		}, {
			config_exists = true,
			has_api_key = false,
			bundle_available = true,
			root_exists = function()
				return true
			end,
		})

		assert(report.ready == false)
		assert(report.output:find('API key: missing', 1, true) ~= nil)
		assert(
			report.output:find('ROBLOX_OPEN_CLOUD_API_KEY', 1, true)
				~= nil
		)
	end
)

t.test('should report missing literal discovery roots', function()
	const missing_root = 'dist/test-tmp/doctor-missing-root'
	const report = inspect({
		lute = {
			roots = { missing_root },
			ignore = {},
			require = '@lutest_release',
			gitignore = true,
		},
		roblox = nil,
		roblox_options = nil,
	}, {
		config_exists = true,
		has_api_key = true,
		bundle_available = true,
	})

	assert(report.ready == false)
	assert(report.output:find('Lute runtime not ready', 1, true) ~= nil)
	assert(
		report.output:find(`unavailable root: {missing_root}`, 1, true)
			~= nil
	)
	assert(
		report.output:find(
			'Create the directory or update discovery.roots in lutest.toml.',
			1,
			true
		) ~= nil
	)
end)

t.test('should not validate glob discovery roots as literal paths', function()
	const report = inspect({
		lute = {
			roots = { 'src/**/*.luau' },
			ignore = {},
			require = '@lutest_release',
			gitignore = true,
		},
		roblox = nil,
		roblox_options = nil,
	}, {
		config_exists = true,
		has_api_key = true,
		bundle_available = true,
		root_exists = function()
			return false
		end,
	})

	assert(report.ready == true)
	assert(report.output:find('Lute runtime ready', 1, true) ~= nil)
end)

return {
	inspect = inspect,
	run = run,
}
