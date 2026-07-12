--!nocheck
-- lute-lint-global-ignore(unused_variable)
local ReplicatedStorage = game:GetService 'ReplicatedStorage'

local t = require(ReplicatedStorage.Packages.lutest)

local leaderstats = {}

function leaderstats.create()
	local container = Instance.new 'Folder'
	container.Name = 'leaderstats'

	local _coins = Instance.new 'IntValue'
	_coins.Name = 'Coins'
	_coins.Value = 0
	_coins.Parent = container

	return container
end

t.test('should create Roblox leaderstats instances', function()
	local stats = leaderstats.create()
	const coins = stats:FindFirstChild 'Coins'

	assert(stats:IsA 'Folder')
	assert(coins ~= nil and coins:IsA 'IntValue')
	assert((coins :: IntValue).Value == 0)

	stats:Destroy()
end)

return leaderstats
