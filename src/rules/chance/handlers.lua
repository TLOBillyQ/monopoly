local common = require("src.rules.chance.handlers.common")
local cash_handlers = require("src.rules.chance.handlers.cash")
local asset_handlers = require("src.rules.chance.handlers.asset")
local movement_handlers = require("src.rules.chance.handlers.movement")

local handlers = {}

function handlers.build()
  local built = {}
  cash_handlers.register(built, common)
  asset_handlers.register(built, common)
  movement_handlers.register(built, common)
  built.handlers = built
  return built
end

return handlers
