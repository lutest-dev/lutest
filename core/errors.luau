const stringext = require '@std/stringext'
const ui = require '@lutest/utils/ui'
const t = require '@lutest_release'

export type ErrorContext = {
	where: string?,
	command: string?,
	highlight: string?,
	suggestion: string?,
	how_to_fix: string?,
	details: string?,
}

const SENTINEL = '\31lutest:'

const function append_context(lines: { string }, value: string?)
	if value == nil or value == '' then return end

	table.insert(lines, '')
	table.insert(lines, ui.section(value))
end

const function append_action(lines: { string }, value: string?)
	if value == nil or value == '' then return end

	table.insert(lines, '')
	table.insert(lines, ui.warned(value))
end

const function build_suggestion_line(suggestion: string?): string?
	if suggestion == nil or suggestion == '' then return nil end

	return `Did you mean {ui.accent.bold(suggestion)}?`
end

const function build_how_to_fix_line(how_to_fix: string?): string?
	if how_to_fix == nil or how_to_fix == '' then return nil end

	return how_to_fix
end

const function format_error(
	kind: string,
	summary: string,
	context: ErrorContext?
): string
	const resolved_context = if context == nil
		then {} :: ErrorContext
		else context
	const lines = { ui.failed(summary) }

	append_context(lines, resolved_context.where)
	append_action(
		lines,
		if resolved_context.suggestion ~= nil
			then build_suggestion_line(resolved_context.suggestion)
			else build_how_to_fix_line(
				resolved_context.how_to_fix
			)
	)
	if
		resolved_context.details ~= nil
		and resolved_context.details ~= ''
	then
		table.insert(lines, '')
		table.insert(lines, ui.section 'Details')
		table.insert(lines, ui.muted(resolved_context.details))
	end

	return `{SENTINEL}{kind}\n{table.concat(lines, '\n')}`
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
	return stringext.hasPrefix(message, SENTINEL)
end

const function display_error(message: string): string
	if not is_lutest_error(message) then return message end

	local _, sentinel_end = message:find('\n', 1, true)
	if sentinel_end == nil then return message end

	return message:sub(sentinel_end + 1)
end

const function strip_ansi(message: string): string
	return (message:gsub('\27%[[0-9;]*m', ''))
end

t.test('should format usage errors with context and suggestions', function()
	const raw_message = usage_error('Test path not found', {
		where = 'rka',
		suggestion = '`core`',
		how_to_fix = 'Pass an existing test file or directory path.',
	})
	const message = strip_ansi(display_error(raw_message))

	assert(raw_message:find(SENTINEL, 1, true) == 1)
	assert(message:find('Test path not found', 1, true) ~= nil)
	assert(message:find('> rka', 1, true) ~= nil)
	assert(message:find('Did you mean `core`?', 1, true) ~= nil)
	assert(message:find('How to fix:', 1, true) == nil)
end)

t.test('should format usage errors with a direct action', function()
	const message =
		strip_ansi(display_error(usage_error('No test files found', {
			how_to_fix = 'Add a test file or update discovery.roots in lutest.toml.',
		})))

	assert(message:find('No test files found', 1, true) ~= nil)
	assert(message:find('How to fix:', 1, true) == nil)
	assert(
		message:find(
			'Add a test file or update discovery.roots in lutest.toml.',
			1,
			true
		) ~= nil
	)
end)

t.test('should format runtime errors with details', function()
	const message = strip_ansi(
		display_error(
			runtime_error(
				'Could not load test file `core/runner.luau`.',
				{
					details = 'boom\nstacktrace:\nline 1',
				}
			)
		)
	)

	assert(message:find('RuntimeError:', 1, true) == nil)
	assert(message:find('> Details', 1, true) ~= nil)
	assert(message:find('stacktrace:', 1, true) ~= nil)
end)

t.test('should detect formatted lutest errors', function()
	assert(is_lutest_error(usage_error('Missing command.', {
		command = 'lutest',
	})) == true)
	assert(is_lutest_error 'plain message' == false)
end)

t.test('should format internal errors with framework guidance', function()
	const message = strip_ansi(
		display_error(
			internal_error(
				'The runner crashed while preparing test suites.',
				{
					where = 'runner',
					how_to_fix = 'Report the command and stack trace to the Lutest maintainers.',
				}
			)
		)
	)

	assert(message:find('InternalError:', 1, true) == nil)
	assert(
		message:find('Report the command and stack trace', 1, true)
			~= nil
	)
end)

return {
	display_error = display_error,
	strip_ansi = strip_ansi,
	configuration_error = configuration_error,
	internal_error = internal_error,
	is_lutest_error = is_lutest_error,
	runtime_error = runtime_error,
	usage_error = usage_error,
}
