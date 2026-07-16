const json = require '@std/json'
const errors = require '@core/errors'
const t = require '@lutest_release'

export type TestResult = {
	name: string,
	kind: 'passed' | 'failed' | 'skipped' | 'todo',
	error_message: string?,
}

export type LifecycleFailure = {
	suite_name: string,
	hook_name: string,
	error_message: string,
}

export type TestSuiteResult = {
	name: string,
	total_tests: number,
	passed_tests: number,
	failed_tests: number,
	skipped_tests: number,
	todo_tests: number,
	results: { TestResult },
	lifecycle_failures: { LifecycleFailure },
	warnings: { string }?,
}

export type LoadFailure = {
	path: string,
	error_message: string,
}

export type DecodedEnvelope = {
	results: { TestSuiteResult },
	load_failures: { LoadFailure },
}

export type HarnessInput = {
	test_paths: { string },
	require_path: string,
	mode: 'test' | 'todo',
}

local RESULT_PREFIX = 'LUTEST_RESULT_V1:'

const function remote_error(summary: string, details: string?): never
	error(
		errors.runtime_error(summary, {
			where = 'Roblox Open Cloud session task',
			how_to_fix = 'Check the task logs and the configured test place, then run the command again.',
			details = details,
		}),
		0
	)
end

const function object(value: json.Value, label: string): json.Object
	const result = json.asObject(value)
	if result == nil then
		remote_error(
			`Invalid Roblox result envelope: {label} must be an object.`
		)
	end
	return result :: json.Object
end

const function array(value: json.Value, label: string): json.Array
	const result = json.asArray(value)
	if result == nil then
		remote_error(
			`Invalid Roblox result envelope: {label} must be an array.`
		)
	end
	return result :: json.Array
end

const function string_value(value: json.Value, label: string): string
	if type(value) ~= 'string' then
		remote_error(
			`Invalid Roblox result envelope: {label} must be a string.`
		)
	end
	return value :: string
end

const function number_value(value: json.Value, label: string): number
	if type(value) ~= 'number' then
		remote_error(
			`Invalid Roblox result envelope: {label} must be a number.`
		)
	end
	return value :: number
end

const function decode_result(value: json.Value): TestResult
	const result = object(value, 'test result')
	const kind = string_value(result.kind, 'test result.kind')
	if
		kind ~= 'passed'
		and kind ~= 'failed'
		and kind ~= 'skipped'
		and kind ~= 'todo'
	then
		remote_error(
			`Invalid Roblox result envelope: unsupported test result kind '{kind}'.`
		)
	end

	const decoded = {
		name = string_value(result.name, 'test result.name'),
		kind = kind,
	} :: any
	if kind == 'failed' then
		decoded.error_message = string_value(
			result.error_message,
			'test result.error_message'
		)
	end
	return decoded :: TestResult
end

const function decode_suite(value: json.Value): TestSuiteResult
	const suite = object(value, 'suite')
	const results = {} :: { TestResult }
	for _, result in array(suite.results, 'suite.results') do
		table.insert(results, decode_result(result))
	end
	const lifecycle_failures = {} :: { LifecycleFailure }
	const encoded_failures = suite.lifecycle_failures
	if encoded_failures ~= nil then
		for _, failure in
			array(encoded_failures, 'suite.lifecycle_failures')
		do
			const decoded = object(failure, 'lifecycle failure')
			table.insert(lifecycle_failures, {
				suite_name = string_value(
					decoded.suite_name,
					'lifecycle failure.suite_name'
				),
				hook_name = string_value(
					decoded.hook_name,
					'lifecycle failure.hook_name'
				),
				error_message = string_value(
					decoded.error_message,
					'lifecycle failure.error_message'
				),
			})
		end
	end
	local warnings = nil :: { string }?
	if suite.warnings ~= nil then
		warnings = {}
		for _, warning in array(suite.warnings, 'suite.warnings') do
			table.insert(
				warnings,
				string_value(warning, 'suite warning')
			)
		end
	end

	return {
		name = string_value(suite.name, 'suite.name'),
		total_tests = number_value(
			suite.total_tests,
			'suite.total_tests'
		),
		passed_tests = number_value(
			suite.passed_tests,
			'suite.passed_tests'
		),
		failed_tests = number_value(
			suite.failed_tests,
			'suite.failed_tests'
		),
		skipped_tests = number_value(
			suite.skipped_tests,
			'suite.skipped_tests'
		),
		todo_tests = number_value(suite.todo_tests, 'suite.todo_tests'),
		results = results,
		lifecycle_failures = lifecycle_failures,
		warnings = warnings,
	}
end

const function decode_load_failure(value: json.Value): LoadFailure
	const failure = object(value, 'load failure')
	return {
		path = string_value(failure.path, 'load failure.path'),
		error_message = string_value(
			failure.error_message,
			'load failure.error_message'
		),
	}
end

const function decode_envelope_line(line: string): DecodedEnvelope
	if line:sub(1, #RESULT_PREFIX) ~= RESULT_PREFIX then
		remote_error(
			'Roblox task completed without a Lutest result envelope.',
			line
		)
	end

	local decoded = nil :: json.Value?
	local decode_error = nil :: string?
	const ok = xpcall(function()
		decoded = json.deserialize(line:sub(#RESULT_PREFIX + 1))
	end, function(err)
		decode_error = tostring(err)
		return decode_error
	end)
	if not ok or decoded == nil then
		remote_error(
			'Could not parse the Roblox result envelope.',
			decode_error
		)
	end

	const envelope = object(decoded :: json.Value, 'envelope')
	if envelope.version ~= 1 then
		remote_error 'Unsupported Roblox result envelope version.'
	end

	const results = {} :: { TestSuiteResult }
	for _, suite in array(envelope.results, 'envelope.results') do
		table.insert(results, decode_suite(suite))
	end

	const load_failures = {} :: { LoadFailure }
	for _, failure in
		array(envelope.load_failures, 'envelope.load_failures')
	do
		table.insert(load_failures, decode_load_failure(failure))
	end

	return {
		results = results,
		load_failures = load_failures,
	}
end

const function decode_logs(logs: { string }): DecodedEnvelope
	local envelope_line = nil :: string?
	for _, line in logs do
		if line:sub(1, #RESULT_PREFIX) ~= RESULT_PREFIX then
			continue
		end
		if envelope_line ~= nil then
			remote_error 'Roblox task emitted multiple Lutest result envelopes.'
		end
		envelope_line = line
	end
	if envelope_line == nil then
		remote_error(
			'Roblox task completed without a Lutest result envelope.',
			table.concat(logs, '\n')
		)
	end
	return decode_envelope_line(envelope_line :: string)
end

t.test('should decode a versioned remote result envelope', function()
	const decoded = decode_logs {
		'normal remote log',
		'LUTEST_RESULT_V1:{"version": 1, "results": [{"name": "suite", "total_tests": 1, "passed_tests": 1, "failed_tests": 0, "skipped_tests": 0, "todo_tests": 0, "results": [{"name": "passes", "kind": "passed"}]}], "load_failures": []}',
	}
	assert(#decoded.results == 1)
	assert(decoded.results[1].results[1].kind == 'passed')
end)

t.test('should decode warnings for empty test suites', function()
	const decoded = decode_logs {
		'LUTEST_RESULT_V1:{"version": 1, "results": [{"name": "src/inventory.luau", "total_tests": 0, "passed_tests": 0, "failed_tests": 0, "skipped_tests": 0, "todo_tests": 0, "results": [], "warnings": ["src/inventory.luau was discovered as a test suite but registered no tests."]}], "load_failures": []}',
	}

	assert(decoded.results[1].warnings ~= nil)
	assert(
		(decoded.results[1].warnings :: { string })[1]
			== 'src/inventory.luau was discovered as a test suite but registered no tests.'
	)
end)

t.test('should reject duplicate remote result envelopes', function()
	const ok = pcall(function()
		decode_logs {
			'LUTEST_RESULT_V1:{"version": 1, "results": [], "load_failures": []}',
			'LUTEST_RESULT_V1:{"version": 1, "results": [], "load_failures": []}',
		}
	end)
	assert(ok == false)
end)

return {
	RESULT_PREFIX = RESULT_PREFIX,
	decode_logs = decode_logs,
}
