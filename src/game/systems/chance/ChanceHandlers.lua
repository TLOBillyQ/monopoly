local common = require("src.game.systems.chance.handlers.Common")
local cash_handlers = require("src.game.systems.chance.handlers.CashHandlers")
local asset_handlers = require("src.game.systems.chance.handlers.AssetHandlers")
local movement_handlers = require("src.game.systems.chance.handlers.MovementHandlers")

local chance_handlers = {}

function chance_handlers.build()
  local handlers = {}
  cash_handlers.register(handlers, common)
  asset_handlers.register(handlers, common)
  movement_handlers.register(handlers, common)
  handlers.handlers = handlers
  return handlers
end

return chance_handlers
