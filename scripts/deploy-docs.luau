const fs = require '@std/fs'
const path = require '@std/path'
const process = require '@std/process'

const DEFAULT_DIST = 'docs/dist'
const DEFAULT_BRANCH = 'gh-pages'
const DEFAULT_REMOTE = 'origin'
const WORKTREE_ROOT = 'dist/.pages-worktrees'

const function normalize_path(value)
	return (path.format(path.normalize(value)):gsub('\\', '/'))
end

const function resolve_path(cwd: string, value: string): string
	if path.isAbsolute(value) then return normalize_path(value) end
	return normalize_path(path.join(cwd, value))
end

const function run(args: { string }, cwd: string)
	const result = process.run(args, {
		cwd = cwd,
		stdio = 'inherit',
	})

	if result.exitcode == 0 then return end
	process.exit(result.exitcode)
end

const function ensure_exists(target: string, label: string)
	if fs.exists(target) then return end
	error(`missing {label}: '{target}'`, 0)
end

const function ensure_directory(target: string)
	if fs.exists(target) then return end

	fs.createDirectory(target, {
		makeParents = true,
	})
end

const function create_worktree_path(cwd: string): string
	const parent = resolve_path(cwd, WORKTREE_ROOT)
	ensure_directory(parent)

	const name = `pages-{os.time()}-{math.random(1000, 9999)}`
	return resolve_path(parent, name)
end

const function remove_worktree(repo_path: string, worktree_path: string)
	run({
		'git',
		'-C',
		repo_path,
		'worktree',
		'remove',
		'--force',
		worktree_path,
	}, repo_path)

	run({
		'git',
		'-C',
		repo_path,
		'worktree',
		'prune',
	}, repo_path)
end

const function copy_directory(source: string, destination: string)
	for _, entry in fs.listDirectory(source) do
		const source_path =
			normalize_path(path.join(source, entry.name))
		const destination_path =
			normalize_path(path.join(destination, entry.name))

		if entry.type == 'dir' then
			fs.createDirectory(destination_path, {
				makeParents = true,
			})
			copy_directory(source_path, destination_path)
			continue
		end

		fs.copy(source_path, destination_path)
	end
end

const function clean_worktree_directory(worktree_path: string)
	for _, entry in fs.listDirectory(worktree_path) do
		if entry.name == '.git' then continue end

		const target_path =
			normalize_path(path.join(worktree_path, entry.name))
		if entry.type == 'dir' then
			fs.removeDirectory(target_path, {
				recursive = true,
			})
			continue
		end

		fs.remove(target_path)
	end
end

const function deploy(
	dist_path: string,
	branch: string,
	remote: string,
	cwd: string
)
	const worktree_path = create_worktree_path(cwd)

	ensure_exists(dist_path, 'docs build output')

	run({
		'git',
		'fetch',
		remote,
		branch,
	}, cwd)

	run({
		'git',
		'worktree',
		'add',
		'--detach',
		worktree_path,
		`{remote}/{branch}`,
	}, cwd)

	clean_worktree_directory(worktree_path)
	copy_directory(dist_path, worktree_path)

	run({
		'git',
		'-C',
		worktree_path,
		'add',
		'-A',
	}, cwd)

	const status = process.run({
		'git',
		'-C',
		worktree_path,
		'status',
		'--short',
	}, {
		cwd = cwd,
	})

	const output = if type(status.stdout) == 'string'
		then status.stdout
		else ''
	if output == '' then
		print 'docs deploy skipped: no changes'
		remove_worktree(cwd, worktree_path)
		return
	end

	run({
		'git',
		'-C',
		worktree_path,
		'commit',
		'-m',
		'docs(pages): sync manual deploy',
	}, cwd)

	run({
		'git',
		'-C',
		worktree_path,
		'push',
		remote,
		`HEAD:{branch}`,
	}, cwd)

	remove_worktree(cwd, worktree_path)

	print(`docs deployed to {remote}/{branch}`)
end

const cwd = normalize_path(process.cwd())
const dist_path = resolve_path(cwd, process.args[2] or DEFAULT_DIST)
const branch = process.args[3] or DEFAULT_BRANCH
const remote = process.args[4] or DEFAULT_REMOTE

deploy(dist_path, branch, remote, cwd)
