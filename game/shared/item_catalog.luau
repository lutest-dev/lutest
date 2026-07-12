--!nocheck
local catalog = {
	apple = {
		id = 'apple',
		name = 'Apple',
		max_stack = 10,
	},
	potion = {
		id = 'potion',
		name = 'Health Potion',
		max_stack = 5,
	},
}

function catalog.get(item_id: string)
	return catalog[item_id]
end

return catalog
