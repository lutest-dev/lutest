const fs = require '@std/fs'
const path = require '@std/path'
const errors = require '@core/errors'
const tint = require '@packages/tint'
const path_utils = require '@lutest/utils/path'
const library = require '@runtimes/roblox/library'
const t = require '@lutest_release'

const DEFAULT_OUTPUT = '.'

const function usage_error(summary: string, how_to_fix: string): never
	error(
		errors.usage_error(summary, {
			command = 'lutest install-package',
			how_to_fix = how_to_fix,
		}),
		0
	)
end

const function output_path(value: string?): string
	const parent = path_utils.resolve_from_cwd(value or DEFAULT_OUTPUT)
	return path_utils.resolve_path(parent, 'lutest')
end

const function write_package(destination: string)
	if fs.exists(destination) then
		usage_error(
			`Package destination already exists: {destination}`,
			'Choose another parent with `lutest install-package --output <parent-directory>`, or remove the existing package first.'
		)
	end

	for _, file in library.files 'package' do
		const output =
			path_utils.resolve_path(destination, file.relative)
		path_utils.ensure_directory(path.dirname(output))
		fs.writeStringToFile(output, file.source)
	end
end

const function format_success(destination: string): string
	const relative = path_utils.relative_to_cwd(destination)
	return table.concat({
		tint.green.bold(`Created Roblox package at ./{relative}`),
		'',
		'Configure `discovery.roblox.require` for the package path in your game.',
		'',
		'local ReplicatedStorage = game:GetService \'ReplicatedStorage\'',
		'local t = require(ReplicatedStorage.lutest)',
	}, '\n')
end

const function run(output: string?)
	const destination = output_path(output)
	write_package(destination)
	print(format_success(destination))
end

t.test('should use a lutest directory by default', function()
	assert(output_path(nil):sub(-7) == '/lutest')
end)

t.test(
	'should create a lutest directory under an explicit output parent',
	function()
		assert(
			output_path('src/Packages'):find(
				'src/Packages/lutest',
				1,
				true
			) ~= nil
		)
	end
)

t.test('should explain how to require the installed package', function()
	const output = format_success 'C:/project/lutest'
	assert(output:find('ReplicatedStorage.lutest', 1, true) ~= nil)
end)

return {
	run = run,
}
