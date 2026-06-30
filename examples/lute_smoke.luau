const core = require '@core'

type TestSpec = core.TestSpec

const tests = {
	{
		name = 'marks passing assertions as successful',
		fn = function()
			assert(1 + 1 == 2, 'expected 1 + 1 to equal 2')
		end,
	},
	{
		name = 'captures assertion failures',
		fn = function()
			assert(
				2 * 2 == 5,
				'expected 2 * 2 to equal 5 for smoke coverage'
			)
		end,
	},
	{
		name = 'keeps later tests running after failures',
		fn = function()
			assert(
				'lute' .. 'st' == 'lutest',
				'expected concatenated string to equal lutest'
			)
		end,
	},
} :: { TestSpec }

return {
	name = 'lute runtime smoke example',
	tests = tests,
}
