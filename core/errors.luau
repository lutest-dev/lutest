const stringext = require '@std/stringext'
const t = require '@lutest_release'

export type ErrorContext = {
	where: string?,
	how_to_fix: string?,
	details: string?,
}

const PREFIX = '[lutest]'

const function append_section(lines: { string }, label: string, value: string?)
	if value == nil or value == '' then return end

	table.insert(lines, '')
	table.insert(lines, `{label}:`)
	table.insert(lines, value)
end

const function format_error(
	kind: string,
	summary: string,
	context: ErrorContext?
): string
	const resolved_context = if context == nil
		then {} :: ErrorContext
		else context
	const lines = { `{PREFIX} {kind}: {summary}` }

	append_section(lines, 'Where', resolved_context.where)
	append_section(lines, 'How to fix', resolved_context.how_to_fix)
	append_section(lines, 'Details', resolved_context.details)

	return table.concat(lines, '\n')
end

const function usage_error(summary: string, context: ErrorContext?): string
	return format_error('UsageError', summary, context)
end

const function configuration_error(
	summary: string,
	context: ErrorContext?
): string
	return format_error('ConfigurationError', summary, context)
end

const function runtime_error(summary: string, context: ErrorContext?): string
	return format_error('RuntimeError', summary, context)
end

const function internal_error(summary: string, context: ErrorContext?): string
	return format_error('InternalError', summary, context)
end

const function is_lutest_error(message: string): boolean
	return stringext.hasPrefix(message, `{PREFIX} `)
end

t.test('should format usage errors with optional sections', function()
	const message =
		usage_error('Could not find test file or directory `rka`.', {
			where = 'lutest test rka',
			how_to_fix = 'Pass an existing test file or directory path.',
		})

	assert(message:find('[lutest] UsageError:', 1, true) ~= nil)
	assert(
		message:find(
			'Could not find test file or directory `rka`.',
			1,
			true
		) ~= nil
	)
	assert(message:find('Where:', 1, true) ~= nil)
	assert(message:find('lutest test rka', 1, true) ~= nil)
	assert(message:find('How to fix:', 1, true) ~= nil)
end)

t.test('should format runtime errors with details', function()
	const message =
		runtime_error('Could not load test file `core/runner.luau`.', {
			details = 'boom\nstacktrace:\nline 1',
		})

	assert(message:find('[lutest] RuntimeError:', 1, true) ~= nil)
	assert(message:find('Details:', 1, true) ~= nil)
	assert(message:find('stacktrace:', 1, true) ~= nil)
end)

t.test('should detect formatted lutest errors', function()
	assert(is_lutest_error '[lutest] UsageError: nope' == true)
	assert(is_lutest_error 'plain message' == false)
end)

t.test('should format internal errors with framework guidance', function()
	const message = internal_error(
		'The runner crashed while preparing test suites.',
		{
			where = 'runner',
			how_to_fix = 'Report the command and stack trace to the Lutest maintainers.',
		}
	)

	assert(message:find('[lutest] InternalError:', 1, true) ~= nil)
	assert(message:find('How to fix:', 1, true) ~= nil)
end)

return {
	configuration_error = configuration_error,
	internal_error = internal_error,
	is_lutest_error = is_lutest_error,
	runtime_error = runtime_error,
	usage_error = usage_error,
}
