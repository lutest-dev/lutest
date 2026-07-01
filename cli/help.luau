const tint = require '@packages/tint'

const function format_help(): string
	return table.concat({
		tint.cyan.bold 'Usage:',
		`  {tint.green 'lutest [paths...]'}`,
		'',
		tint.cyan.bold 'Description:',
		'  Discover and run test modules from the given files or directories.',
		'  Without paths, uses roots from lutest.toml or defaults to ".".',
		'',
		tint.cyan.bold 'Examples:',
		`  {tint.green 'lutest'}`,
		`  {tint.green 'lutest .'}`,
		`  {tint.green 'lutest src'}`,
		`  {tint.green 'lutest src packages'}`,
	}, '\n')
end

const function print_help()
	print(format_help())
end

return {
	format_help = format_help,
	print_help = print_help,
}
