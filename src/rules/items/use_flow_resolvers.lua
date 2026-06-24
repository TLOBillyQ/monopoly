local achievement_progress = require("src.rules.ports.achievement_progress")
local demolish = require("src.rules.items.demolish")
local executor = require("src.rules.items.executor")
local inventory = require("src.rules.items.inventory")
local item_use_broadcast = require("src.rules.items.use_broadcast")
local remote_dice = require("src.rules.items.remote_dice")
local roadblock = require("src.rules.items.roadblock")
local intent_output_port = require("src.rules.ports.intent_output")
local flow_context = require("src.rules.items.use_flow_context")
local flow_result = require("src.rules.items.use_flow_result")

local resolvers = {}

local function _consume_if_needed(player, item_id, already_consumed)
  if item_id == nil or already_consumed == true then
    return
  end
  assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
end

local function _publish_success(game, player, item_id, raw_result)
  if not flow_result.raw_result_ok(raw_result) then
    return
  end
  achievement_progress.item_used(game, player)
  item_use_broadcast.dispatch(game, player, item_id)
end

local function _resolve_target_player_choice(game, _choice, action, use_context, meta, player, item_id)
  local before_count = flow_context.count_item(player, item_id)
  local raw_result = executor.use_item(game, player, item_id, {
    target_id = action.option_id,
    item_preconsumed = meta.item_preconsumed == true,
    by_ai = use_context.by_ai,
  })
  return flow_result.normalize_effect(raw_result, player, item_id, before_count, meta, "invalid_target")
end

local function _resolve_remote_dice_choice(game, _choice, action, _use_context, meta, player, item_id)
  local before_count = flow_context.count_item(player, item_id)
  local dice_count = meta.dice_count or game:player_dice_count(player)
  _consume_if_needed(player, item_id, meta.item_preconsumed)
  local raw_result = remote_dice.apply(game, player, dice_count, action.option_id)
  _publish_success(game, player, item_id, raw_result)
  return flow_result.normalize_effect(raw_result, player, item_id, before_count, meta, "effect_rejected")
end

local function _resolve_roadblock_choice(game, _choice, action, _use_context, meta, player, item_id)
  if not roadblock.is_ui_candidate(game, player, action.option_id) then
    return flow_result.rejected("invalid_target", { actor = player, actor_id = player.id, item_id = item_id })
  end
  local before_count = flow_context.count_item(player, item_id)
  _consume_if_needed(player, item_id, meta.item_preconsumed)
  local raw_result = roadblock.apply(game, player, action.option_id)
  _publish_success(game, player, item_id, raw_result)
  intent_output_port.dispatch(game, raw_result)
  return flow_result.normalize_effect(raw_result, player, item_id, before_count, meta, "effect_rejected")
end

local function _resolve_demolish_choice(game, _choice, action, _use_context, meta, player, item_id)
  local before_count = flow_context.count_item(player, item_id)
  _consume_if_needed(player, item_id, meta.item_preconsumed)
  local raw_result = demolish.apply(game, player, action.option_id, {
    injure = meta.injure,
    title = meta.title,
    item_id = item_id,
  })
  _publish_success(game, player, item_id, raw_result)
  local intent = type(raw_result) == "table" and raw_result.intent or {}
  intent_output_port.dispatch(game, intent)
  return flow_result.normalize_effect(raw_result, player, item_id, before_count, meta, "effect_rejected")
end

local choice_resolvers = {
  item_target_player = _resolve_target_player_choice,
  remote_dice_value = _resolve_remote_dice_choice,
  roadblock_target = _resolve_roadblock_choice,
  demolish_target = _resolve_demolish_choice,
}

function resolvers.resolve(game, choice, action, use_context, meta, player, item_id)
  local resolver = choice_resolvers[choice.kind]
  if resolver == nil then
    return flow_result.rejected("unsupported_choice_kind", {
      actor = player,
      actor_id = player.id,
      item_id = item_id,
      choice = choice,
    })
  end
  return resolver(game, choice, action, use_context, meta, player, item_id)
end

return resolvers
