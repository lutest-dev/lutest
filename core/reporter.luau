const types = require '@core/types'
const tint = require '@packages/tint'

export type TestSuiteResult = types.TestSuiteResult
export type FailedTestResult = types.FailedTestResult

const function format_suite_result(result: TestSuiteResult): string
	const suite_status = if result.failed_tests == 0
		then tint.green.bold '(OK)'
		else tint.red.bold '(FAIL)'
	const summary =
		`suite: {tint.cyan(result.name)}\nresult: {suite_status}; {result.total_tests} tests, {tint.green(
			`{result.passed_tests} passed`
		)}, {tint.red(`{result.failed_tests} failed`)}, {tint.yellow(
			`{result.skipped_tests} skipped`
		)}, {tint.magenta(`{result.todo_tests} todo`)}`

	if result.failed_tests == 0 then return summary end
	const lines = { tint.red.bold 'failures:', '' }

	for _, test_result in result.results do
		if test_result.kind ~= 'failed' then continue end

		const failed_test = test_result :: FailedTestResult
		table.insert(
			lines,
			tint.red(`── {failed_test.name} stdout ──`)
		)
		table.insert(lines, failed_test.error_message)
		table.insert(lines, '')
	end

	table.insert(lines, summary)
	return table.concat(lines, '\n')
end

const function print_suite_result(result: TestSuiteResult)
	print(format_suite_result(result))
end

return {
	format_suite_result = format_suite_result,
	print_suite_result = print_suite_result,
}
