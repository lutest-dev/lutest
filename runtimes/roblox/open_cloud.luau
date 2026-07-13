const json = require '@std/json'
const net = require '@std/net'
const task = require '@std/task'
const errors = require '@core/errors'
const t = require '@lutest_release'

export type Config = {
	universe_id: number,
	place_id: number,
	version_id: number?,
	poll_interval_seconds: number,
	timeout_seconds: number,
}

export type Client = {
	request: (url: string, metadata: net.Metadata?) -> net.Response,
	wait: (seconds: number) -> number,
	clock: () -> number,
}

export type CompletedTask = {
	logs: { string },
	task_path: string,
}

const BASE_URL = 'https://apis.roblox.com/cloud/v2'

const function api_error(operation: string, response: net.Response): never
	const summary = if response.status == 401
		then 'Roblox could not authenticate'
		else 'Roblox request failed'
	error(
		errors.runtime_error(summary, {
			where = `HTTP {response.status} while {operation}`,
			how_to_fix = 'Check the API key, place configuration, and network access.',
		}),
		0
	)
end

const function object(body: string, operation: string): json.Object
	local decoded = nil :: json.Value?
	local parse_error = nil :: string?
	const ok = xpcall(function()
		decoded = json.deserialize(body)
	end, function(err)
		parse_error = tostring(err)
		return parse_error
	end)
	if
		not ok
		or decoded == nil
		or json.asObject(decoded :: json.Value) == nil
	then
		error(
			errors.runtime_error(
				`Roblox Open Cloud returned an invalid {operation} response.`,
				{
					where = 'Roblox Open Cloud',
					details = parse_error,
				}
			),
			0
		)
	end
	return json.asObject(decoded :: json.Value) :: json.Object
end

const function string_field(
	value: json.Object,
	field: string,
	operation: string
): string
	if type(value[field]) ~= 'string' then
		error(
			errors.runtime_error(
				`Roblox Open Cloud response is missing {field}.`,
				{
					where = operation,
				}
			),
			0
		)
	end
	return value[field] :: string
end

const function headers(api_key: string): { [string]: string }
	return {
		['x-api-key'] = api_key,
	}
end

const function task_url(config: Config): string
	const base =
		`{BASE_URL}/universes/{config.universe_id}/places/{config.place_id}`
	if config.version_id == nil then
		return `{base}/luau-execution-session-tasks`
	end
	return `{base}/versions/{config.version_id}/luau-execution-session-tasks`
end

const function api_url(resource_path: string): string
	if resource_path:sub(1, 8) == 'https://' then return resource_path end
	return `https://apis.roblox.com/cloud/v2/{resource_path}`
end

const function upload_binary_input(
	client: Client,
	config: Config,
	api_key: string,
	bundle: string
): string
	const create_url =
		`{BASE_URL}/universes/{config.universe_id}/luau-execution-session-task-binary-inputs`
	const create_response = client.request(create_url, {
		method = 'POST',
		headers = {
			['x-api-key'] = api_key,
			['content-type'] = 'application/json',
		},
		body = json.serialize(json.object { size = #bundle }),
	})
	if not create_response.ok then
		api_error('create a binary input', create_response)
	end
	const input = object(create_response.body, 'binary input')
	const upload_uri = string_field(input, 'uploadUri', 'binary input')
	const input_path = string_field(input, 'path', 'binary input')
	const upload_response = client.request(upload_uri, {
		method = 'PUT',
		headers = {
			['content-type'] = 'application/octet-stream',
		},
		body = bundle,
	})
	if not upload_response.ok then
		api_error('upload the RBXM bundle', upload_response)
	end
	return input_path
end

const function create_task(
	client: Client,
	config: Config,
	api_key: string,
	script_source: string,
	binary_input: string
): string
	const response = client.request(task_url(config), {
		method = 'POST',
		headers = {
			['x-api-key'] = api_key,
			['content-type'] = 'application/json',
		},
		body = json.serialize(json.object {
			script = script_source,
			binaryInput = binary_input,
		}),
	})
	if not response.ok then
		api_error('create a Luau execution task', response)
	end
	return string_field(
		object(response.body, 'task creation'),
		'path',
		'task creation'
	)
end

const function append_log_messages(logs: { string }, group_value: json.Value)
	const group = json.asObject(group_value)
	if group == nil then return end

	const messages = json.asArray(group.messages)
	if messages == nil then return end

	for _, message in messages do
		if type(message) == 'string' then
			table.insert(logs, message)
		end
	end
end

const function task_logs(
	client: Client,
	api_key: string,
	resource_path: string
): { string }
	const response =
		client.request(`{api_url(resource_path)}/logs?view=FLAT`, {
			headers = headers(api_key),
		})
	if not response.ok then api_error('fetch task logs', response) end
	const body = object(response.body, 'task logs')
	const groups = json.asArray(body.luauExecutionSessionTaskLogs)
	if groups == nil then return {} end

	const logs = {} :: { string }
	for _, group_value in groups do
		append_log_messages(logs, group_value)
	end
	return logs
end

const function wait_for_completion(
	client: Client,
	config: Config,
	api_key: string,
	resource_path: string
): CompletedTask
	const started_at = client.clock()
	while client.clock() - started_at < config.timeout_seconds do
		client.wait(config.poll_interval_seconds)
		const response = client.request(api_url(resource_path), {
			headers = headers(api_key),
		})
		if not response.ok then
			api_error('poll the execution task', response)
		end
		const task_value = object(response.body, 'execution task')
		const state =
			string_field(task_value, 'state', 'execution task')
		if state == 'COMPLETE' then
			return {
				logs = task_logs(
					client,
					api_key,
					resource_path
				),
				task_path = resource_path,
			}
		end
		if state == 'FAILED' or state == 'CANCELLED' then
			error(
				errors.runtime_error(
					`Roblox execution task ended as {state}.`,
					{
						where = resource_path,
						details = table.concat(
							task_logs(
								client,
								api_key,
								resource_path
							),
							'\n'
						),
					}
				),
				0
			)
		end
	end

	local logs = {} :: { string }
	pcall(function()
		logs = task_logs(client, api_key, resource_path)
	end)
	error(
		errors.runtime_error('Roblox execution task timed out.', {
			where = resource_path,
			how_to_fix = 'Increase timeout_seconds up to 300, or reduce the remote test batch.',
			details = table.concat(logs, '\n'),
		}),
		0
	)
end

const function run(
	client: Client,
	config: Config,
	api_key: string,
	bundle: string,
	script_source: string,
	on_stage: ((string) -> ())?
): CompletedTask
	if on_stage ~= nil then on_stage 'uploading bundle' end
	const input_path = upload_binary_input(client, config, api_key, bundle)
	if on_stage ~= nil then on_stage 'starting session' end
	const resource_path =
		create_task(client, config, api_key, script_source, input_path)
	if on_stage ~= nil then on_stage 'running tests' end
	const completed =
		wait_for_completion(client, config, api_key, resource_path)
	if on_stage ~= nil then on_stage 'collecting results' end
	return completed
end

const function default_client(): Client
	return {
		request = net.request,
		wait = task.wait,
		clock = os.clock,
	}
end

t.test('should select the versioned task endpoint', function()
	assert(task_url({
		universe_id = 1,
		place_id = 2,
		version_id = 3,
		poll_interval_seconds = 2,
		timeout_seconds = 300,
	}):find('/versions/3/', 1, true) ~= nil)
end)

t.test(
	'should upload, run, poll, and collect logs through the injected client',
	function()
		local request_count = 0
		const completed = run({
			request = function(_, metadata)
				request_count += 1
				if request_count == 1 then
					assert(metadata ~= nil)
					assert(
						(metadata :: net.Metadata).method
							== 'POST'
					)
					return {
						ok = true,
						status = 200,
						headers = {},
						body = '{"uploadUri":"https://upload","path":"universes/1/inputs/one"}',
					}
				end
				if request_count == 2 then
					return {
						ok = true,
						status = 200,
						headers = {},
						body = '',
					}
				end
				if request_count == 3 then
					return {
						ok = true,
						status = 200,
						headers = {},
						body = '{"path":"universes/1/tasks/one"}',
					}
				end
				if request_count == 4 then
					return {
						ok = true,
						status = 200,
						headers = {},
						body = '{"state":"COMPLETE"}',
					}
				end
				return {
					ok = true,
					status = 200,
					headers = {},
					body = '{"luauExecutionSessionTaskLogs":[{"messages":["LUTEST_RESULT_V1:{}"]}]}',
				}
			end,
			wait = function()
				return 0
			end,
			clock = function()
				return 0
			end,
		}, {
			universe_id = 1,
			place_id = 2,
			poll_interval_seconds = 1,
			timeout_seconds = 2,
		}, 'key', 'bundle', 'script')
		assert(completed.logs[1] == 'LUTEST_RESULT_V1:{}')
		assert(request_count == 5)
	end
)

return {
	default_client = default_client,
	run = run,
	task_url = task_url,
}
