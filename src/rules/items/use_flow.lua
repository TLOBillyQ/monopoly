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
version=4
projectHash=0d0e7f19ee960579
scope.0.id=chunk:src/rules/items/use_flow.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=33
scope.0.semanticHash=70ce3ef59c6e61b7
scope.1.id=function:use_flow.begin_item_use
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=20
scope.1.semanticHash=6e0668ff674948f0
scope.2.id=function:use_flow.resolve_item_use_choice
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=30
scope.2.semanticHash=b12a60eb0aa0c38a
]]
