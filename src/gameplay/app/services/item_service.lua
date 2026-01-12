-- Thin facade: authoritative item rule logic lives in src/gameplay/effects/item.lua.
-- Keep this module as a stable service entrypoint for game.services.item.

local ItemEffects = require("src.gameplay.effects.item")

local ItemService = {}

setmetatable(ItemService, { __index = ItemEffects })

return ItemService
