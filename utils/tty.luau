const process = require '@std/process'
const system = require '@std/system'

type ProcessResult = {
	ok: boolean,
}

type ProcessRunOptions = process.ProcessRunOptions

type ProcessRunner = (
	args: { string },
	options: ProcessRunOptions
) -> ProcessResult

const function tty_probe_command(is_windows: boolean): { string }
	if is_windows then
		return {
			'powershell.exe',
			'-NoProfile',
			'-NonInteractive',
			'-Command',
			'if ([Console]::IsOutputRedirected) { exit 1 }; exit 0',
		}
	end

	return {
		'sh',
		'-c',
		'test -t 1',
	}
end

const function probe_stdout_is_tty(
	is_windows: boolean,
	run: ProcessRunner
): boolean
	const ok, result = pcall(function()
		return run(tty_probe_command(is_windows), {
			stdio = 'inherit',
		})
	end)

	if not ok then return false end
	return (result :: ProcessResult).ok
end

const function stdout_is_tty(): boolean
	return probe_stdout_is_tty(system.win32, function(args, options)
		return process.run(args, options)
	end)
end

return {
	stdout_is_tty = stdout_is_tty,
}
