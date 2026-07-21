const t = require '@lutest_release'
const version = require '@core/version'

const function format_version(): string
	return `lutest {version.VALUE}`
end

const function print_version()
	print(format_version())
end

t.test('should format version output', function()
	assert(format_version() == 'lutest 0.7.1')
end)

return {
	format_version = format_version,
	print_version = print_version,
}
