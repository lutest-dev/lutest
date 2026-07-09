const stringext = require '@std/stringext'
const tint = require '@packages/tint'
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

const function colorize_summary(kind: string, summary: string): string
	if kind == 'UsageError' then return tint.yellow.bold(summary) end
	if kind == 'ConfigurationError' then
		return tint.magenta.bold(summary)
	end
	if kind == 'RuntimeError' then return tint.red.bold(summary) end
	if kind == 'InternalError' then return tint.red.bold(summary) end

	return tint.bold(summary)
end

const function append_section(lines: { string }, label: string, value: string?)
	if value == nil or value == '' then return end

	table.insert(lines, '')
	table.insert(lines, tint.cyan.bold(`{label}:`))
	table.insert(lines, value)
end

const function append_line(lines: { string }, value: string?)
	if value == nil or value == '' then return end

	table.insert(lines, '')
	table.insert(lines, value)
end

const function build_pointer_line(command: string, highlight: string?): string?
	if highlight == nil or highlight == '' then return nil end

	local start_index = nil :: number?
	local search_from = 1

	while true do
		const next_index = command:find(highlight, search_from, true)
		if next_index == nil then break end

		start_index = next_index
		search_from = next_index + 1
	end

	if start_index == nil then return nil end

	return string.rep(' ', start_index - 1)
		.. tint.red.bold(string.rep('^', math.max(#highlight, 1)))
end

const function build_where_block(context: ErrorContext): string?
	if context.command == nil or context.command == '' then
		return context.where
	end

	const lines = { tint.bold(`  {context.command}`) }
	const pointer_line =
		build_pointer_line(context.command, context.highlight)
	if pointer_line ~= nil then table.insert(lines, `  {pointer_line}`) end
	if context.where ~= nil and context.where ~= '' then
		table.insert(lines, `  {context.where}`)
	end

	return table.concat(lines, '\n')
end

const function build_suggestion_line(suggestion: string?): string?
	if suggestion == nil or suggestion == '' then return nil end

	return `  Did you mean {tint.green.bold(suggestion)}?`
end

const function build_how_to_fix_line(how_to_fix: string?): string?
	if how_to_fix == nil or how_to_fix == '' then return nil end

	return `  {how_to_fix}`
end

const function should_use_compact_format(context: ErrorContext): boolean
	if context.details ~= nil and context.details ~= '' then
		return false
	end

	return context.command ~= nil and context.command ~= ''
end

const function format_error(
	kind: string,
	summary: string,
	context: ErrorContext?
): string
	const resolved_context = if context == nil
		then {} :: ErrorContext
		else context
	const compact = should_use_compact_format(resolved_context)
	const lines = {
		if kind == 'UsageError' and compact
			then colorize_summary(kind, summary)
			else `{kind}: {colorize_summary(kind, summary)}`,
	}

	if compact then
		append_line(lines, build_where_block(resolved_context))
		append_line(
			lines,
			if resolved_context.suggestion ~= nil
				then build_suggestion_line(
					resolved_context.suggestion
				)
				else build_how_to_fix_line(
					resolved_context.how_to_fix
				)
		)

		return `{SENTINEL}{kind}\n{table.concat(lines, '\n')}`
	end

	append_section(lines, 'Where', build_where_block(resolved_context))
	append_section(
		lines,
		'Did you mean',
		if resolved_context.suggestion == nil
			then nil
			else `  {tint.green.bold(
				resolved_context.suggestion
			)}`
	)
	append_section(lines, 'How to fix', resolved_context.how_to_fix)
	append_section(
		lines,
		'Details',
		if resolved_context.details == nil
			then nil
			else tint.dim(resolved_context.details)
	)

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

t.test('should format compact usage errors with suggestions', function()
	const raw_message =
		usage_error('Could not find test file or directory `rka`.', {
			command = 'lutest test rka',
			highlight = 'rka',
			suggestion = '`core`',
			how_to_fix = 'Pass an existing test file or directory path.',
		})
	const message = strip_ansi(display_error(raw_message))

	assert(raw_message:find(SENTINEL, 1, true) == 1)
	assert(
		message:find(
			'Could not find test file or directory `rka`.',
			1,
			true
		) ~= nil
	)
	assert(message:find('lutest test rka', 1, true) ~= nil)
	assert(message:find('^^^', 1, true) ~= nil)
	assert(message:find('Where:', 1, true) == nil)
	assert(message:find('Did you mean `core`?', 1, true) ~= nil)
	assert(message:find('How to fix:', 1, true) == nil)
end)

t.test('should format compact usage errors without suggestion', function()
	const message = strip_ansi(
		display_error(usage_error('No test files were discovered.', {
			command = 'lutest test',
			how_to_fix = 'Pass an existing test file or directory, or update `discovery.roots` in `lutest.toml`.',
		}))
	)

	assert(message:find('No test files were discovered.', 1, true) ~= nil)
	assert(message:find('lutest test', 1, true) ~= nil)
	assert(message:find('Where:', 1, true) == nil)
	assert(message:find('How to fix:', 1, true) == nil)
	assert(
		message:find(
			'Pass an existing test file or directory, or update `discovery.roots` in `lutest.toml`.',
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

	assert(message:find('RuntimeError:', 1, true) ~= nil)
	assert(message:find('Details:', 1, true) ~= nil)
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

	assert(message:find('InternalError:', 1, true) ~= nil)
	assert(message:find('How to fix:', 1, true) ~= nil)
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
