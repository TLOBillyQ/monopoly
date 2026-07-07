local item_handlers = require("src.rules.choice_handlers.item")
local land_handlers = require("src.rules.choice_handlers.land")
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

function choice_handler_factory.build_market_handlers(helpers)
  return _build(market_handlers, helpers)
end

return choice_handler_factory

--[[ mutate4lua-manifest
version=2
projectHash=bb7d295eabdfb87f
scope.0.id=chunk:src/rules/choice_handlers/factory.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=26
scope.0.semanticHash=46db7aa88f849b72
scope.0.lastMutatedAt=2026-07-07T03:30:29Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:_build:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=11
scope.1.semanticHash=37fd39a3f934b6c3
scope.1.lastMutatedAt=2026-07-07T03:30:29Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:choice_handler_factory.build_item_handlers:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=15
scope.2.semanticHash=130c34f4bf320e4b
scope.2.lastMutatedAt=2026-07-07T03:30:29Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:choice_handler_factory.build_land_handlers:17
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=19
scope.3.semanticHash=b7a7b9d5afe30953
scope.3.lastMutatedAt=2026-07-07T03:30:29Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:choice_handler_factory.build_market_handlers:21
scope.4.kind=function
scope.4.startLine=21
scope.4.endLine=23
scope.4.semanticHash=5ea7a33b2486085f
scope.4.lastMutatedAt=2026-07-07T03:30:29Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
]]
