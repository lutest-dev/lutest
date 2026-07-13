const t = require '@lutest_release'

const VERSION = '0.5.0'

const function format_version(): string
	return `lutest {VERSION}`
end

const function print_version()
	print(format_version())
end

t.test('should format version output', function()
	assert(format_version() == 'lutest 0.5.0')
end)

return {
	VERSION = VERSION,
	format_version = format_version,
	print_version = print_version,
}
