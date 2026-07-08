local flow_context = require("src.rules.items.use_flow_context")

local result = {}

local function _build_result(base, extra)
  for key, value in pairs(extra or {}) do
    base[key] = value
  end
  return base
end

function result.rejected(reason, extra)
  return _build_result({
    ok = false,
    status = "rejected",
    reason = reason,
  }, extra)
end

function result.raw_result_ok(raw_result)
  if type(raw_result) == "table" then
    if raw_result.waiting == true then
      return true
    end
    if type(raw_result.ok) == "boolean" then
      return raw_result.ok
    end
    return true
  end
  return raw_result == true
end

local function _result_reason(raw_result, fallback)
  if type(raw_result) == "table" then
    if raw_result.reason ~= nil then
      return raw_result.reason
    end
    if raw_result.bag_full == true then
      return "bag_full"
    end
  end
  return fallback
end

local function _choice_spec_from_result(raw_result)
  local intent = type(raw_result) == "table" and raw_result.intent or nil
  return type(intent) == "table" and intent.choice_spec or nil
end

local function _waiting_choice(raw_result, player, item_id)
  local choice_spec = _choice_spec_from_result(raw_result)
  return {
    ok = true,
    status = "waiting_choice",
    waiting = true,
    actor = player,
    actor_id = player and player.id or nil,
    item_id = item_id,
    item_consumed = false,
    choice_spec = choice_spec,
    choice = choice_spec,
    intent = type(raw_result) == "table" and raw_result.intent or nil,
    result = raw_result,
  }
end

local function _item_consumed(player, item_id, before_count, use_context, raw_result)
  if use_context and use_context.item_preconsumed == true then
    return true
  end
  if type(raw_result) == "table" and raw_result.item_consumed == true then
    return true
  end
  return flow_context.count_item(player, item_id) < before_count
end

local function _applied(raw_result, player, item_id, before_count, use_context)
  return {
    ok = true,
    status = "applied",
    actor = player,
    actor_id = player and player.id or nil,
    item_id = item_id,
    item_consumed = _item_consumed(player, item_id, before_count, use_context, raw_result),
    action_anim = type(raw_result) == "table" and raw_result.action_anim or nil,
    after_action_anim = type(raw_result) == "table" and raw_result.after_action_anim or nil,
    result = raw_result,
  }
end

function result.normalize_effect(raw_result, player, item_id, before_count, use_context, fallback_reason)
  if type(raw_result) == "table" and raw_result._settled_item_use == true then
    return raw_result
  end
  if type(raw_result) == "table" and raw_result.waiting == true then
    return _waiting_choice(raw_result, player, item_id)
  end
  if not result.raw_result_ok(raw_result) then
    return result.rejected(_result_reason(raw_result, fallback_reason or "effect_rejected"), {
      actor = player,
      actor_id = player and player.id or nil,
      item_id = item_id,
      item_consumed = _item_consumed(player, item_id, before_count, use_context, raw_result),
      result = raw_result,
    })
  end
  return _applied(raw_result, player, item_id, before_count, use_context)
end

return result

--[[ mutate4lua-manifest
version=2
projectHash=1af2044ad3aff9cf
scope.0.id=chunk:src/rules/items/use_flow_result.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=108
scope.0.semanticHash=f2bb0355c009657e
scope.0.lastMutatedAt=2026-06-24T08:40:24Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:result.rejected:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=18
scope.1.semanticHash=2c07127cfff76830
scope.1.lastMutatedAt=2026-06-24T08:40:24Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:result.raw_result_ok:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=31
scope.2.semanticHash=e791d4f6cec1a65b
scope.2.lastMutatedAt=2026-06-24T08:40:24Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=12
scope.2.lastMutationKilled=12
scope.3.id=function:_result_reason:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=43
scope.3.semanticHash=73745e4f55e73d5e
scope.3.lastMutatedAt=2026-06-24T08:40:24Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
scope.4.id=function:_choice_spec_from_result:45
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=48
scope.4.semanticHash=a6ab89243e4aa19b
scope.4.lastMutatedAt=2026-06-24T08:40:24Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=10
scope.4.lastMutationKilled=10
scope.5.id=function:_waiting_choice:50
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=65
scope.5.semanticHash=961d13128231a9b0
scope.5.lastMutatedAt=2026-06-24T08:40:24Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=12
scope.5.lastMutationKilled=12
scope.6.id=function:_item_consumed:67
scope.6.kind=function
scope.6.startLine=67
scope.6.endLine=75
scope.6.semanticHash=6423e5118ff1f0a5
scope.6.lastMutatedAt=2026-06-24T08:40:24Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=13
scope.6.lastMutationKilled=13
scope.7.id=function:_applied:77
scope.7.kind=function
scope.7.startLine=77
scope.7.endLine=89
scope.7.semanticHash=6ae6dcd9d221ba4b
scope.7.lastMutatedAt=2026-06-24T08:40:24Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=15
scope.7.lastMutationKilled=15
scope.8.id=function:result.normalize_effect:91
scope.8.kind=function
scope.8.startLine=91
scope.8.endLine=105
scope.8.semanticHash=8c76b99c8a055450
scope.8.lastMutatedAt=2026-06-24T08:40:24Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=11
scope.8.lastMutationKilled=11
]]
