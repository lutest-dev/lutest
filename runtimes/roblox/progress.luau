const io = require '@std/io'
const task = require '@std/task'
const version = require '@core/version'
const output = require '@self/output'
const tty = require '@lutest/utils/tty'
const ui = require '@lutest/utils/ui'
const t = require '@lutest_release'

type Output = (message: string) -> ()

local FRAMES =
	{ '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
const STAGE_INDEX = {
	['preparing bundle'] = 1,
	['uploading bundle'] = 2,
	['starting session'] = 3,
	['running tests'] = 4,
	['collecting results'] = 5,
}
const STAGE_COUNT = 5

const function plain_message(stage: string): string
	const index = STAGE_INDEX[stage]
	assert(index ~= nil, `Unknown Roblox progress stage '{stage}'.`)
	return `{output.non_interactive_prefix()} [{index}/{STAGE_COUNT}] {stage}`
end

const function create(is_tty: boolean, output: Output?)
	const write = output or function(message)
		print(message)
	end
	local frame = 1
	local previous_width = 0
	local active = false
	local spinner_thread = nil :: thread?
	local current_stage = ''

	const function render_spinner()
		const message =
			`{ui.accent(FRAMES[frame])} Roblox {ui.muted '-'} {current_stage}`
		frame = if frame == #FRAMES then 1 else frame + 1
		const width = math.max(previous_width, #message)
		io.write(`\r{message}{string.rep(' ', width - #message)}`)
		previous_width = #message
	end

	const function start_spinner()
		if spinner_thread ~= nil then return end
		active = true
		spinner_thread = task.spawn(function()
			while active do
				render_spinner()
				task.wait(0.08)
			end
		end)
	end

	const function update(stage: string)
		if not is_tty then
			write(plain_message(stage))
			return
		end

		current_stage = stage
		start_spinner()
	end

	const function finish()
		if not is_tty then return end
		active = false
		if spinner_thread ~= nil then
			task.cancel(spinner_thread :: thread)
		end
		spinner_thread = nil
		if previous_width == 0 then return end
		io.write(`\r{string.rep(' ', previous_width)}\r`)
		previous_width = 0
	end

	return {
		update = update,
		finish = finish,
	}
end

const function default_progress()
	return create(tty.stdout_is_tty())
end

t.test('should print stable progress lines without a TTY', function()
	const output = {} :: { string }
	const progress = create(false, function(message)
		table.insert(output, message)
	end)
	progress.update 'preparing bundle'
	progress.update 'uploading bundle'
	progress.update 'starting session'
	progress.update 'running tests'
	progress.update 'collecting results'
	const plain_output = table.concat(output, '\n'):gsub('\27%[[%d;]*m', '')
	const prefix = `lutest(roblox)@{version.VALUE}`
	assert(plain_output == table.concat({
		`{prefix} [1/5] preparing bundle`,
		`{prefix} [2/5] uploading bundle`,
		`{prefix} [3/5] starting session`,
		`{prefix} [4/5] running tests`,
		`{prefix} [5/5] collecting results`,
	}, '\n'))
end)

return {
	create = create,
	default_progress = default_progress,
}
