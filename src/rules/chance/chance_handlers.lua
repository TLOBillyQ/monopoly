local common = require("src.rules.chance.handlers.common")
local cash_handlers = require("src.rules.chance.handlers.cash_handlers")
local asset_handlers = require("src.rules.chance.handlers.asset_handlers")
local movement_handlers = require("src.rules.chance.handlers.movement_handlers")

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
