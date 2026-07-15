const ui = require '@lutest/utils/ui'
const t = require '@lutest_release'

const function format_help(): string
	return table.concat({
		ui.accent.bold 'Lutest',
		ui.muted 'Co-located tests for Luau modules.',
		'',
		ui.section 'Commands',
		'  test [paths...] [--runtime lute|roblox] [--config <path>] [--dry-run]',
		'  todo [paths...] [--runtime lute|roblox] [--config <path>] [--dry-run]',
		'  doctor [--config <path>]',
		'  setup',
		'  version',
		'',
		ui.section 'Try',
		'  lutest test game --runtime roblox',
	}, '\n')
end

const function print_help()
	print(format_help())
end

t.test('should format concise help with usage and examples', function()
	const output = format_help()

	assert(
		output:find('Co-located tests for Luau modules.', 1, true)
			~= nil
	)
	assert(output:find('> Commands', 1, true) ~= nil)
	assert(output:find('install-package', 1, true) == nil)
	assert(output:find('setup', 1, true) ~= nil)
	assert(
		output:find(
			'test [paths...] [--runtime lute|roblox] [--config <path>] [--dry-run]',
			1,
			true
		) ~= nil
	)
	assert(output:find('doctor [--config <path>]', 1, true) ~= nil)
	assert(
		output:find(
			'todo [paths...] [--runtime lute|roblox] [--config <path>] [--dry-run]',
			1,
			true
		) ~= nil
	)
	assert(output:find('version', 1, true) ~= nil)
	assert(output:find('> Try', 1, true) ~= nil)
	assert(output:find('lutest --help', 1, true) == nil)
	assert(output:find('lutest test game --runtime roblox', 1, true) ~= nil)
	assert(output:find('Description', 1, true) == nil)
end)

return {
	format_help = format_help,
	print_help = print_help,
}
