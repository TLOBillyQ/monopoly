local executor = require("src.rules.items.executor")
local flow_context = require("src.rules.items.use_flow_context")
local flow_result = require("src.rules.items.use_flow_result")
local flow_validation = require("src.rules.items.use_flow_validation")
local resolvers = require("src.rules.items.use_flow_resolvers")

local use_flow = {}

function use_flow.begin_item_use(game, actor_id, item_id, context)
  local player = flow_context.resolve_actor(game, actor_id)
  local resolved_context = flow_context.copy(context)
  local invalid = flow_validation.validate_begin(game, player, item_id, resolved_context)
  if invalid ~= nil then
    return invalid
  end

  resolved_context.reject_reason_fallback = resolved_context.reject_reason_fallback or "no_candidates"
  local raw_result = executor.use_item(game, player, item_id, resolved_context)
  return flow_result.normalize_effect(raw_result, player, item_id)
end

function use_flow.resolve_item_use_choice(game, choice, action, context)
  local resolved_context = flow_context.copy(context)
  local meta, player, item_id, invalid = flow_validation.validate_choice(game, choice, action, resolved_context)
  if invalid ~= nil then
    return invalid
  end

  return resolvers.resolve(game, choice, action, resolved_context, meta, player, item_id)
end

return use_flow

--[[ mutate4lua-manifest
version=2
projectHash=13eb2255583d3560
scope.0.id=chunk:src/rules/items/use_flow.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=33
scope.0.semanticHash=07ac7be47ab43ecd
scope.0.lastMutatedAt=2026-06-24T08:35:45Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=5
scope.0.lastMutationKilled=5
scope.1.id=function:use_flow.begin_item_use:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=20
scope.1.semanticHash=5d8e1a4ba3087799
scope.1.lastMutatedAt=2026-06-24T08:35:45Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:use_flow.resolve_item_use_choice:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=30
scope.2.semanticHash=60998fa5a046143d
scope.2.lastMutatedAt=2026-06-24T08:35:45Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
]]
