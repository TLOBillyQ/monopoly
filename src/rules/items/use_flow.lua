local achievement_progress = require("src.rules.ports.achievement_progress")
local availability = require("src.rules.items.availability")
local demolish = require("src.rules.items.demolish")
local executor = require("src.rules.items.executor")
local inventory = require("src.rules.items.inventory")
local item_use_broadcast = require("src.rules.items.use_broadcast")
local remote_dice = require("src.rules.items.remote_dice")
local roadblock = require("src.rules.items.roadblock")
local intent_output_port = require("src.rules.ports.intent_output")

local use_flow = {}

local function _copy_context(context)
  local next_context = {}
  if type(context) ~= "table" then
    return next_context
  end
  for key, value in pairs(context) do
    next_context[key] = value
  end
  return next_context
end

local function _resolve_actor(game, actor_id)
  if type(actor_id) == "table" then
    return actor_id
  end
  if game and type(game.find_player_by_id) == "function" then
    return game:find_player_by_id(actor_id)
  end
  for _, player in ipairs(game and game.players or {}) do
    if player.id == actor_id then
      return player
    end
  end
  return nil
end

local function _count_item(player, item_id)
  local count = 0
  for _, item in ipairs(inventory.items(player)) do
    if item.id == item_id then
      count = count + 1
    end
  end
  return count
end

local function _build_result(base, extra)
  for key, value in pairs(extra or {}) do
    base[key] = value
  end
  return base
end

local function _rejected(reason, extra)
  return _build_result({
    ok = false,
    status = "rejected",
    reason = reason,
  }, extra)
end

local function _raw_result_ok(raw_result)
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

local function _item_consumed(player, item_id, before_count, context, raw_result)
  if context and context.item_preconsumed == true then
    return true
  end
  if type(raw_result) == "table" and raw_result.item_consumed == true then
    return true
  end
  return _count_item(player, item_id) < before_count
end

local function _applied(raw_result, player, item_id, before_count, context)
  return {
    ok = true,
    status = "applied",
    actor = player,
    actor_id = player and player.id or nil,
    item_id = item_id,
    item_consumed = _item_consumed(player, item_id, before_count, context, raw_result),
    action_anim = type(raw_result) == "table" and raw_result.action_anim or nil,
    after_action_anim = type(raw_result) == "table" and raw_result.after_action_anim or nil,
    result = raw_result,
  }
end

local function _normalize_effect_result(raw_result, player, item_id, before_count, context, fallback_reason)
  if type(raw_result) == "table" and raw_result.waiting == true then
    return _waiting_choice(raw_result, player, item_id)
  end
  if not _raw_result_ok(raw_result) then
    return _rejected(_result_reason(raw_result, fallback_reason or "effect_rejected"), {
      actor = player,
      actor_id = player and player.id or nil,
      item_id = item_id,
      item_consumed = _item_consumed(player, item_id, before_count, context, raw_result),
      result = raw_result,
    })
  end
  return _applied(raw_result, player, item_id, before_count, context)
end

local function _validate_begin(game, player, item_id, context)
  if game == nil then
    return _rejected("missing_game")
  end
  if player == nil then
    return _rejected("missing_actor", { item_id = item_id })
  end
  if inventory.cfg(item_id) == nil then
    return _rejected("missing_item_cfg", { actor = player, actor_id = player.id, item_id = item_id })
  end
  if inventory.find_index(player, item_id) == nil then
    return _rejected("item_not_in_inventory", { actor = player, actor_id = player.id, item_id = item_id })
  end
  if context.phase ~= nil then
    local can_offer, deny_reason = availability.can_offer_in_phase(game, player, item_id, context.phase)
    if can_offer ~= true then
      return _rejected(deny_reason or "item_unavailable", { actor = player, actor_id = player.id, item_id = item_id })
    end
  end
  return nil
end

function use_flow.begin_item_use(game, actor_id, item_id, context)
  local player = _resolve_actor(game, actor_id)
  local resolved_context = _copy_context(context)
  local invalid = _validate_begin(game, player, item_id, resolved_context)
  if invalid ~= nil then
    return invalid
  end

  local before_count = _count_item(player, item_id)
  local raw_result = executor.use_item(game, player, item_id, resolved_context)
  return _normalize_effect_result(raw_result, player, item_id, before_count, resolved_context, "no_candidates")
end

local function _option_matches(option, option_id)
  return option == option_id
    or tostring(option) == tostring(option_id)
    or (type(option) == "table" and (option.id == option_id or tostring(option.id) == tostring(option_id)))
end

local function _choice_has_option(choice, option_id)
  for _, option in ipairs(choice and choice.options or {}) do
    if _option_matches(option, option_id) then
      return true
    end
  end
  return false
end

local function _validate_choice(game, choice, action, context)
  if game == nil then
    return nil, nil, nil, _rejected("missing_game")
  end
  if type(choice) ~= "table" then
    return nil, nil, nil, _rejected("missing_choice")
  end
  if action == nil then
    return nil, nil, nil, _rejected("missing_action", { choice = choice })
  end
  if action.choice_id ~= nil and choice.id ~= nil and tostring(action.choice_id) ~= tostring(choice.id) then
    return nil, nil, nil, _rejected("choice_mismatch", { choice = choice })
  end
  local meta = choice.meta or {}
  local player = _resolve_actor(game, meta.player_id)
  if player == nil then
    return nil, nil, nil, _rejected("missing_actor", { choice = choice })
  end
  if action.actor_role_id ~= nil and tostring(action.actor_role_id) ~= tostring(player.id) then
    return nil, nil, nil, _rejected("actor_mismatch", { actor = player, actor_id = player.id, choice = choice })
  end
  if context.item_id ~= nil and meta.item_id ~= nil and tostring(context.item_id) ~= tostring(meta.item_id) then
    return nil, nil, nil, _rejected("item_mismatch", { actor = player, actor_id = player.id, choice = choice })
  end
  if not _choice_has_option(choice, action.option_id) then
    return nil, nil, nil, _rejected("invalid_option", { actor = player, actor_id = player.id, choice = choice })
  end
  return meta, player, meta.item_id or context.item_id, nil
end

local function _consume_if_needed(player, item_id, already_consumed)
  if item_id == nil or already_consumed == true then
    return
  end
  assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
end

local function _publish_success(game, player, item_id, raw_result)
  if not _raw_result_ok(raw_result) then
    return
  end
  achievement_progress.item_used(game, player)
  item_use_broadcast.dispatch(game, player, item_id)
end

local function _resolve_target_player_choice(game, choice, action, context, meta, player, item_id)
  local before_count = _count_item(player, item_id)
  local raw_result = executor.use_item(game, player, item_id, {
    target_id = action.option_id,
    item_preconsumed = meta.item_preconsumed == true,
    by_ai = context.by_ai,
  })
  return _normalize_effect_result(raw_result, player, item_id, before_count, meta, "invalid_target")
end

local function _resolve_remote_dice_choice(game, _, action, _, meta, player, item_id)
  local before_count = _count_item(player, item_id)
  local dice_count = meta.dice_count or game:player_dice_count(player)
  _consume_if_needed(player, item_id, meta.item_preconsumed)
  local raw_result = remote_dice.apply(game, player, dice_count, action.option_id)
  _publish_success(game, player, item_id, raw_result)
  return _normalize_effect_result(raw_result, player, item_id, before_count, meta, "effect_rejected")
end

local function _resolve_roadblock_choice(game, _, action, _, meta, player, item_id)
  if not roadblock.is_ui_candidate(game, player, action.option_id) then
    return _rejected("invalid_target", { actor = player, actor_id = player.id, item_id = item_id })
  end
  local before_count = _count_item(player, item_id)
  _consume_if_needed(player, item_id, meta.item_preconsumed)
  local raw_result = roadblock.apply(game, player, action.option_id)
  _publish_success(game, player, item_id, raw_result)
  intent_output_port.dispatch(game, raw_result)
  return _normalize_effect_result(raw_result, player, item_id, before_count, meta, "effect_rejected")
end

local function _resolve_demolish_choice(game, _, action, _, meta, player, item_id)
  local before_count = _count_item(player, item_id)
  _consume_if_needed(player, item_id, meta.item_preconsumed)
  local raw_result = demolish.apply(game, player, action.option_id, {
    injure = meta.injure,
    title = meta.title,
    item_id = item_id,
  })
  _publish_success(game, player, item_id, raw_result)
  local intent = type(raw_result) == "table" and raw_result.intent or {}
  intent_output_port.dispatch(game, intent)
  return _normalize_effect_result(raw_result, player, item_id, before_count, meta, "effect_rejected")
end

local choice_resolvers = {
  item_target_player = _resolve_target_player_choice,
  remote_dice_value = _resolve_remote_dice_choice,
  roadblock_target = _resolve_roadblock_choice,
  demolish_target = _resolve_demolish_choice,
}

function use_flow.resolve_item_use_choice(game, choice, action, context)
  local resolved_context = _copy_context(context)
  local meta, player, item_id, invalid = _validate_choice(game, choice, action, resolved_context)
  if invalid ~= nil then
    return invalid
  end
  local resolver = choice_resolvers[choice.kind]
  if resolver == nil then
    return _rejected("unsupported_choice_kind", {
      actor = player,
      actor_id = player.id,
      item_id = item_id,
      choice = choice,
    })
  end
  return resolver(game, choice, action, resolved_context, meta, player, item_id)
end

return use_flow
