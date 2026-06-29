local core = require("@core")
local reporter = require("@core/reporter")

type TestSpec = core.TestSpec

local tests = {
	{
		name = "reports failed assertion for unequal numbers",
		fn = function()
			assert(1 == 2, "expected 1 to equal 2 for failure reporting")
		end,
	},
	{
		name = "marks successful assertion as passed",
		fn = function()
			assert(1 == 1, "expected 1 to equal 1 for passing case")
		end,
	},
	{
		name = "records multiple failing assertions independently",
		fn = function()
			assert(1 == 2, "expected 1 to equal 2 for second failure case")
		end,
	},
} :: { TestSpec }

local suite_result = core.run({
	name = "core runner smoke example",
	tests = tests,
})

reporter.print_suite_result(suite_result)
