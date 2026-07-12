--!nocheck
-- lute-lint-global-ignore(unused_variable)
local ReplicatedStorage = game:GetService 'ReplicatedStorage'

local catalog = require(script.Parent.item_catalog)
local t = require(ReplicatedStorage.Packages.lutest)

local inventory = {}

function inventory.new(capacity: number)
	return {
		capacity = capacity,
		slots = {},
	}
end

function inventory.quantity(state, item_id: string): number
	return state.slots[item_id] or 0
end

local function occupied_slots(state): number
	local count = 0
	for _ in state.slots do
		count += 1
	end
	return count
end

function inventory.add(state, item_id: string, quantity: number): boolean
	local item = catalog.get(item_id)
	if item == nil or quantity <= 0 then return false end

	local current = inventory.quantity(state, item_id)
	if current == 0 and occupied_slots(state) >= state.capacity then
		return false
	end
	if current + quantity > item.max_stack then return false end

	state.slots[item_id] = current + quantity
	return true
end

t.test('should reject an item stack above its catalog limit', function()
	local bag = inventory.new(2)
	assert(inventory.add(bag, 'potion', 5))
	assert(not inventory.add(bag, 'potion', 1))
	assert(inventory.quantity(bag, 'potion') == 5)
end)

t.test('should reject a new item when the inventory is full', function()
	local bag = inventory.new(1)
	assert(inventory.add(bag, 'apple', 1))
	assert(not inventory.add(bag, 'potion', 1))
end)

return inventory
