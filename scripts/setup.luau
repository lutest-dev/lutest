const fs = require '@std/fs'
const process = require '@std/process'

type SetupCommand = {
	name: string,
	args: { string },
}

const function add_command_if_manifest_exists(
	commands: { SetupCommand },
	manifest: string,
	command: SetupCommand
)
	if not fs.exists(manifest) then return end
	table.insert(commands, command)
end

const function commands(): { SetupCommand }
	const setup_commands = {} :: { SetupCommand }

	add_command_if_manifest_exists(setup_commands, 'package.json', {
		name = 'Node.js dependencies',
		args = {
			'mise',
			'exec',
			'--',
			'pnpm',
			'install',
			'--frozen-lockfile',
		},
	})
	add_command_if_manifest_exists(setup_commands, 'pesde.toml', {
		name = 'Pesde dependencies',
		args = { 'mise', 'exec', '--', 'pesde', 'install' },
	})
	add_command_if_manifest_exists(setup_commands, 'loom.config.luau', {
		name = 'Loom dependencies',
		args = { 'mise', 'exec', '--', 'lute', 'pkg', 'install' },
	})
	add_command_if_manifest_exists(setup_commands, '.config.luau', {
		name = 'Lute type definitions',
		args = { 'mise', 'exec', '--', 'lute', 'setup' },
	})
	add_command_if_manifest_exists(
		setup_commands,
		'scripts/ensure-roblox-defs.luau',
		{
			name = 'Roblox type definitions',
			args = {
				'mise',
				'exec',
				'--',
				'lute',
				'run',
				'scripts/ensure-roblox-defs.luau',
			},
		}
	)

	return setup_commands
end

const function run(command: SetupCommand)
	print(`Installing {command.name}...`)
	const result = process.run(command.args, { stdio = 'inherit' })
	if result.exitcode ~= 0 then process.exit(result.exitcode) end
end

for _, command in commands() do
	run(command)
end

if fs.exists 'loom.lock.luau' then
	run {
		name = 'Loom lockfile formatting',
		args = { 'mise', 'exec', '--', 'stylua', 'loom.lock.luau' },
	}
end

print 'Project setup complete.'
