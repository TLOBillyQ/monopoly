local item_handlers = require("src.rules.choice_handlers.item")
local land_handlers = require("src.rules.choice_handlers.land")
local landing_optional_handlers = require("src.rules.choice_handlers.landing_optional")
local market_handlers = require("src.rules.choice_handlers.market")

local choice_handler_factory = {}

local function _build(handler_module, helpers)
  local registry = {}
  handler_module.register(registry, helpers)
  return registry
end

function choice_handler_factory.build_item_handlers(helpers)
  return _build(item_handlers, helpers)
end

function choice_handler_factory.build_land_handlers(helpers)
  return _build(land_handlers, helpers)
end

function choice_handler_factory.build_landing_optional_handlers(helpers)
  return _build(landing_optional_handlers, helpers)
end

function choice_handler_factory.build_market_handlers(helpers)
  return _build(market_handlers, helpers)
end

return choice_handler_factory

--[[ mutate4lua-manifest
version=4
projectHash=5fe75945d36494e7
scope.0.id=chunk:src/rules/choice_handlers/factory.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=31
scope.0.semanticHash=d22a49560d8cc2e6
scope.1.id=function:_build
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=12
scope.1.semanticHash=6ece6e923ee940a0
scope.2.id=function:choice_handler_factory.build_item_handlers
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=e504e513aab7d79c
scope.3.id=function:choice_handler_factory.build_land_handlers
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=20
scope.3.semanticHash=e504e513aab7d79c
scope.4.id=function:choice_handler_factory.build_landing_optional_handlers
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=24
scope.4.semanticHash=e504e513aab7d79c
scope.5.id=function:choice_handler_factory.build_market_handlers
scope.5.kind=function
scope.5.startLine=26
scope.5.endLine=28
scope.5.semanticHash=e504e513aab7d79c
]]
