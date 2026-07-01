const tint = require '@packages/tint'

const function format_help(): string
	return table.concat({
		tint.cyan.bold 'Usage:',
		`  {tint.green 'lute cli/init.luau [paths...]'}`,
		'',
		tint.cyan.bold 'Description:',
		'  Discover and run test modules from the given files or directories.',
		'  Without paths, uses roots from lutest.toml or defaults to ".".',
		'',
		tint.cyan.bold 'Discovery:',
		'  - modules must require the path configured by [discovery].require',
		'  - discovered modules become implicit suites by path',
		'  - lutest.toml supports [discovery].require, roots, and ignore',
		'',
		tint.cyan.bold 'Examples:',
		`  {tint.green 'lute cli/init.luau'}`,
		`  {tint.green 'lute cli/init.luau .'}`,
		`  {tint.green 'lute cli/init.luau tests'}`,
		`  {tint.green 'lute cli/init.luau src tests'}`,
	}, '\n')
end

const function print_help()
	print(format_help())
end

return {
	format_help = format_help,
	print_help = print_help,
}
