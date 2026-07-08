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
    reject_reason_fallback = "invalid_target",
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

--[[ mutate4lua-manifest
version=2
projectHash=a31c7030c398c29f
scope.0.id=chunk:src/rules/items/use_flow_resolvers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=95
scope.0.semanticHash=ead79bdd9effaecb
scope.0.lastMutatedAt=2026-06-24T08:42:05Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=10
scope.0.lastMutationKilled=10
scope.1.id=function:_consume_if_needed:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=19
scope.1.semanticHash=f0c6ed6144afda3e
scope.1.lastMutatedAt=2026-06-24T08:42:05Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_publish_success:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=27
scope.2.semanticHash=7e0285667e1330d3
scope.2.lastMutatedAt=2026-06-24T08:42:05Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_resolve_target_player_choice:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=37
scope.3.semanticHash=4f8b5e4789083aca
scope.3.lastMutatedAt=2026-06-24T08:42:05Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:_resolve_remote_dice_choice:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=46
scope.4.semanticHash=3b466b47da4cfa95
scope.4.lastMutatedAt=2026-06-24T08:42:05Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=7
scope.5.id=function:_resolve_roadblock_choice:48
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=58
scope.5.semanticHash=adbfbff8afbbd785
scope.5.lastMutatedAt=2026-06-24T08:42:05Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=9
scope.5.lastMutationKilled=9
scope.6.id=function:_resolve_demolish_choice:60
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=72
scope.6.semanticHash=b4f4507e4ce6b26a
scope.6.lastMutatedAt=2026-06-24T08:42:05Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=11
scope.6.lastMutationKilled=11
scope.7.id=function:resolvers.resolve:81
scope.7.kind=function
scope.7.startLine=81
scope.7.endLine=92
scope.7.semanticHash=4938cfb2401f05db
scope.7.lastMutatedAt=2026-06-24T08:42:05Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
]]
