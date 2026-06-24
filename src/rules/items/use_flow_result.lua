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
