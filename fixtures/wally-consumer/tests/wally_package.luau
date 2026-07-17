local ReplicatedStorage = game:GetService 'ReplicatedStorage'
local t = (require :: any)((ReplicatedStorage :: any).Packages.lutest)

local sequence = {}

t.suite('Wally package consumer', function()
	t.before_each(function()
		table.insert(sequence, 'before')
	end)

	t.test('should execute through the packaged library', function()
		assert(t.is_running())
		table.insert(sequence, 'test')
	end)

	t.after_each(function()
		assert(table.concat(sequence, ',') == 'before,test')
	end)
end)
