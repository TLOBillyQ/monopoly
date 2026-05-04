local item_handlers = require("src.rules.choice_handlers.item")
local land_handlers = require("src.rules.choice_handlers.land")
local market_handlers = require("src.rules.choice_handlers.market")

local choice_handler_factory = {}

function choice_handler_factory.build_item_handlers(helpers)
  local registry = {}
  item_handlers.register(registry, helpers)
  return registry
end

function choice_handler_factory.build_land_handlers(helpers)
  local registry = {}
  land_handlers.register(registry, helpers)
  return registry
end

function choice_handler_factory.build_market_handlers(helpers)
  local registry = {}
  market_handlers.register(registry, helpers)
  return registry
end

return choice_handler_factory
