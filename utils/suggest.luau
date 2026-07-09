const t = require '@lutest_release'

const function levenshtein_distance(left: string, right: string): number
	if left == right then return 0 end
	if #left == 0 then return #right end
	if #right == 0 then return #left end

	const previous = table.create(#right + 1, 0)
	const current = table.create(#right + 1, 0)

	for column = 0, #right do
		previous[column + 1] = column
	end

	for row = 1, #left do
		current[1] = row

		for column = 1, #right do
			const substitution_cost = if left:sub(row, row)
					== right:sub(column, column)
				then 0
				else 1
			const deletion = previous[column + 1] + 1
			const insertion = current[column] + 1
			const substitution = previous[column]
				+ substitution_cost

			current[column + 1] =
				math.min(deletion, insertion, substitution)
		end

		for column = 1, #right + 1 do
			previous[column] = current[column]
		end
	end

	return previous[#right + 1]
end

const function suggestion_threshold(left: string, right: string): number
	return math.max(1, math.floor(math.max(#left, #right) / 3))
end

const function closest_match(input: string, candidates: { string }): string?
	const normalized_input = string.lower(input)
	local best_match = nil :: string?
	local best_distance = math.huge

	for _, candidate in candidates do
		const normalized_candidate = string.lower(candidate)
		const distance = levenshtein_distance(
			normalized_input,
			normalized_candidate
		)
		if distance >= best_distance then continue end

		best_match = candidate
		best_distance = distance
	end

	if best_match == nil then return nil end
	if
		best_distance
		> suggestion_threshold(normalized_input, best_match)
	then
		return nil
	end

	return best_match
end

t.test('should compute levenshtein distance', function()
	assert(levenshtein_distance('coree', 'core') == 1)
	assert(levenshtein_distance('test', 'test') == 0)
	assert(levenshtein_distance('', 'abc') == 3)
end)

t.test('should return the closest reasonable suggestion', function()
	const suggestion = closest_match('coree', {
		'core',
		'cli',
		'utils',
	})

	assert(suggestion == 'core')
end)

t.test('should avoid weak suggestions', function()
	const suggestion = closest_match('banana', {
		'core',
		'cli',
		'utils',
	})

	assert(suggestion == nil)
end)

return {
	closest_match = closest_match,
	levenshtein_distance = levenshtein_distance,
}
