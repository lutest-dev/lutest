const tint = require '@packages/tint'
const t = require '@lutest_release'

const function format_help(): string
	return table.concat({
		tint.cyan.bold 'Usage:',
		`  {tint.green 'lutest setup'}`,
		`  {tint.green 'lutest test [paths...] [--runtime lute|roblox]'}`,
		`  {tint.green 'lutest todo [paths...] [--runtime lute|roblox]'}`,
		`  {tint.green 'lutest version'}`,
		`  {tint.green 'lutest help'}`,
		'',
		tint.cyan.bold 'Description:',
		'  Run Lutest subcommands.',
		'  The setup command creates an initial lutest.toml configuration.',
		'  The test command discovers and runs test modules from the given files or directories.',
		'  Without --runtime, Lutest uses the local lute runtime.',
		'  Without test paths, uses roots from lutest.toml or defaults to ".".',
		'',
		tint.cyan.bold 'Examples:',
		`  {tint.green 'lutest setup'}`,
		`  {tint.green 'lutest test'}`,
		`  {tint.green 'lutest test .'}`,
		`  {tint.green 'lutest test src'}`,
		`  {tint.green 'lutest test src packages'}`,
		`  {tint.green 'lutest test src --runtime roblox'}`,
		`  {tint.green 'lutest todo'}`,
		`  {tint.green 'lutest todo core'}`,
		`  {tint.green 'lutest version'}`,
		`  {tint.green 'lutest help'}`,
	}, '\n')
end

const function print_help()
	print(format_help())
end

t.test('should format help with usage, description, and examples', function()
	const output = format_help()

	assert(output:find('Usage:', 1, true) ~= nil)
	assert(output:find('lutest setup', 1, true) ~= nil)
	assert(
		output:find(
			'lutest test [paths...] [--runtime lute|roblox]',
			1,
			true
		) ~= nil
	)
	assert(
		output:find(
			'The setup command creates an initial lutest.toml configuration.',
			1,
			true
		) ~= nil
	)
	assert(
		output:find(
			'lutest todo [paths...] [--runtime lute|roblox]',
			1,
			true
		) ~= nil
	)
	assert(output:find('lutest version', 1, true) ~= nil)
	assert(output:find('lutest help', 1, true) ~= nil)
	assert(output:find('lutest --help', 1, true) == nil)
	assert(output:find('Description:', 1, true) ~= nil)
	assert(
		output:find(
			'The test command discovers and runs test modules from the given files or directories.',
			1,
			true
		) ~= nil
	)
	assert(output:find('Examples:', 1, true) ~= nil)
	assert(output:find('lutest test src packages', 1, true) ~= nil)
	assert(output:find('lutest test src --runtime roblox', 1, true) ~= nil)
	assert(output:find('lutest todo core', 1, true) ~= nil)
end)

return {
	format_help = format_help,
	print_help = print_help,
}
