--!nocheck
-- lute-lint-global-ignore(unused_variable)
local ReplicatedStorage = game:GetService 'ReplicatedStorage'

local inventory = require(script.Parent.Parent.shared.inventory)
local t = require(ReplicatedStorage.Packages.lutest)

local inventory_service = {}

function inventory_service.create_for_player(player_id: number)
	local bag = inventory.new(12)
	bag.player_id = player_id
	inventory.add(bag, 'apple', 3)
	return bag
end

t.test('should create a server-owned starter inventory', function()
	local bag = inventory_service.create_for_player(42)
	assert(bag.player_id == 42)
	assert(inventory.quantity(bag, 'apple') == 3)
end)

return inventory_service
