const process = require '@std/process'
const system = require '@std/system'
const t = require '@lutest_release'

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

t.test('should use the Unix TTY probe command', function()
	local received_args = nil :: { string }?

	const is_tty = probe_stdout_is_tty(false, function(args)
		received_args = args
		return {
			ok = true,
		}
	end)

	assert(is_tty)
	assert(received_args ~= nil)
	assert((received_args :: { string })[1] == 'sh')
	assert((received_args :: { string })[3] == 'test -t 1')
end)

t.test('should use the Windows TTY probe command', function()
	local received_args = nil :: { string }?

	const is_tty = probe_stdout_is_tty(true, function(args)
		received_args = args
		return {
			ok = true,
		}
	end)

	assert(is_tty)
	assert(received_args ~= nil)
	assert((received_args :: { string })[1] == 'powershell.exe')
	assert(
		(received_args :: { string })[5]:find(
			'IsOutputRedirected',
			1,
			true
		) ~= nil
	)
end)

t.test('should inherit stdout while probing for a TTY', function()
	local received_stdio = nil :: 'inherit'?

	const is_tty = probe_stdout_is_tty(false, function(_, options)
		assert(options.stdio == 'inherit')
		received_stdio = options.stdio
		return {
			ok = true,
		}
	end)

	assert(is_tty)
	assert(received_stdio == 'inherit')
end)

t.test('should fall back when the TTY probe fails', function()
	const is_tty = probe_stdout_is_tty(false, function()
		error 'shell is unavailable'
	end)

	assert(is_tty == false)
end)

return {
	stdout_is_tty = stdout_is_tty,
}
