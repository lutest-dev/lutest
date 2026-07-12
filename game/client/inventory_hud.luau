--!nocheck
-- lute-lint-global-ignore(unused_variable)
local ReplicatedStorage = game:GetService 'ReplicatedStorage'

local catalog = require(script.Parent.Parent.shared.item_catalog)
local t = require(ReplicatedStorage.Packages.lutest)

local inventory_hud = {}

function inventory_hud.format_slot(item_id: string, quantity: number): string
	local item = catalog.get(item_id)
	if item == nil then return 'Unknown item' end
	return `{item.name} x{quantity}`
end

t.test('should format an inventory slot without client-only APIs', function()
	assert(inventory_hud.format_slot('potion', 2) == 'Health Potion x2')
end)

return inventory_hud
