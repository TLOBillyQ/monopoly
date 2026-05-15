local availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")
local inventory = require("src.rules.items.inventory")
local intent_output_port = require("src.rules.ports.intent_output")
local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")
local demolish = require("src.rules.items.demolish")
local item_use_broadcast = require("src.rules.items.use_broadcast")
local logger = require("src.foundation.log")
local roadblock = require("src.rules.items.roadblock")
local remote_dice = require("src.rules.items.remote_dice")

local copy_table = availability.copy_table
local normalize_integer_field = availability.normalize_integer_field

local normalize = {}

normalize.copy_table = copy_table
normalize.normalize_integer_field = normalize_integer_field

function normalize.choice_action_option_id(choice_kind, action)
  local normalized_action = copy_table(action)
  normalize_integer_field(normalized_action, "option_id", choice_kind, "action", true)
  return normalized_action
end

function normalize.validate_item_player(game, choice_kind, meta)
  return assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
end

function normalize.validate_item_target(game, field_name, meta)
  return assert(game:find_player_by_id(meta[field_name]), "missing " .. tostring(field_name) .. ": " .. tostring(meta[field_name]))
end

function normalize.consume_if_needed(player, item_id, already_consumed)
  if not item_id or already_consumed == true then
    return
  end
  assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
end

function normalize.is_repeatable_phase_meta(meta)
  return type(meta) == "table" and item_phase.is_repeatable(meta.phase)
end

function normalize.finish_item_phase_by_name(game, phase)
  if type(phase) ~= "string" or phase == "" then
    return
  end
  item_phase.finish(game, phase)
end

function normalize.merge_after_action_anim(result, final_res)
  if type(result) == "table" and type(result.after_action_anim) == "table" then
    final_res.after_action_anim = result.after_action_anim
  end
  return final_res
end

function normalize.owner_meta(choice_kind, meta, choice_spec)
  local normalized_meta = copy_table(meta)
  normalize_integer_field(normalized_meta, "player_id", choice_kind)
  choice_spec.owner_role_id = choice_spec.owner_role_id or normalized_meta.player_id
  return normalized_meta
end

function normalize.item_phase_meta(_, meta, choice_spec)
  local normalized_meta = normalize.owner_meta(choice_spec.kind, meta, choice_spec)
  assert(type(normalized_meta.phase) == "string" and normalized_meta.phase ~= "",
    tostring(choice_spec.kind) .. " requires string meta.phase")
  return normalized_meta
end

function normalize.validate_item_phase_meta(game, meta, choice_spec)
  normalize.validate_item_player(game, choice_spec.kind, meta)
  assert(item_phase.is_enabled(meta.phase), tostring(choice_spec.kind) .. " requires enabled meta.phase")
end

function normalize.validate_item_owner_meta(game, meta, choice_spec)
  normalize.validate_item_player(game, choice_spec.kind, meta)
end

function normalize.item_target_meta(_, meta, choice_spec)
  local normalized_meta = normalize.owner_meta(choice_spec.kind, meta, choice_spec)
  normalize_integer_field(normalized_meta, "item_id", choice_spec.kind)
  return normalized_meta
end

function normalize.remote_dice_meta(_, meta, choice_spec)
  local normalized_meta = normalize.item_target_meta(nil, meta, choice_spec)
  normalize_integer_field(normalized_meta, "dice_count", choice_spec.kind)
  return normalized_meta
end

function normalize.validate_remote_dice_meta(game, meta, choice_spec)
  normalize.validate_item_owner_meta(game, meta, choice_spec)
  if meta.dice_count ~= nil then
    assert(meta.dice_count >= 1, tostring(choice_spec.kind) .. " requires positive meta.dice_count")
  end
end

local completions = {}

function completions.build(helpers)
  local finish_choice = helpers.finish_choice

  local function _finish_followup_choice(game)
    helpers.finish_active_item_phase(game)
    return finish_choice(game, false)
  end

  local function _resume_pre_action_phase(game, player, meta)
    if not item_phase.reopen_or_finish(game, player, meta) then
      return finish_choice(game, false)
    end
    if game.turn.action_anim then
      return {
        after_action_anim = {
          next_state = "wait_choice",
          next_args = item_phase.build_wait_choice_args(meta),
        },
      }
    end
    return { stay = true }
  end

  local function _resolve_phase_completion(game, player, meta, result)
    if not normalize.is_repeatable_phase_meta(meta) then
      normalize.finish_item_phase_by_name(game, meta and meta.phase or nil)
      return normalize.merge_after_action_anim(result, finish_choice(game, false))
    end
    if meta.phase == "post_action" then
      return normalize.merge_after_action_anim(result, finish_choice(game, false))
    end
    local resumed = _resume_pre_action_phase(game, player, meta)
    if resumed.stay then
      return resumed
    end
    return normalize.merge_after_action_anim(result, resumed)
  end

  local function _resolve_followup_completion(game, choice, player, result)
    local meta = choice.meta or {}
    if meta.passive_origin and meta.item_id then
      availability.mark_effect_group_used(game, meta.item_id)
    end
    if normalize.is_repeatable_phase_meta(meta) then
      return _resolve_phase_completion(game, player, meta, result)
    end
    return normalize.merge_after_action_anim(result, _finish_followup_choice(game))
  end

  local function _resolve_followup_cancel(game, choice)
    local meta = choice and choice.meta or nil
    if normalize.is_repeatable_phase_meta(meta) then
      if meta.phase == "pre_action" then
        local player = normalize.validate_item_player(game, choice.kind, meta)
        if item_phase.reopen_or_finish(game, player, meta) then
          return { stay = true }
        end
      end
      return nil
    end
    local phase = game.turn.item_phase_active
    if phase and phase ~= "" then
      item_phase.finish(game, phase)
    end
    return nil
  end

  return {
    phase_completion = _resolve_phase_completion,
    followup_completion = _resolve_followup_completion,
    followup_cancel = _resolve_followup_cancel,
  }
end

function completions.item_target_handler(kind, execute_fn, complete, opts)
  opts = opts or {}
  return {
    required_meta = { "player_id", "item_id" },
    cancel = {
      resolve = function(game, choice)
        return complete.followup_cancel(game, choice)
      end,
    },
    normalize_meta = opts.normalize_meta or normalize.item_target_meta,
    meta_validator = opts.meta_validator or normalize.validate_item_owner_meta,
    normalize_action = function(_, _, action)
      return normalize.choice_action_option_id(kind, action)
    end,
    execute = execute_fn,
  }
end

local function _build_phase_handlers(helpers)
  local complete = completions.build(helpers)
  local use_item = helpers.use_item

  local function _handle_item_phase_choice(game, choice, action)
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local phase = meta.phase
    local item_id = action.option_id

    local result = use_item(game, player, item_id)
    if type(result) == "table" and result.waiting then
      local intent = result.intent or {}
      local choice_spec = intent.choice_spec
      if type(choice_spec) == "table" then
        if item_phase.is_repeatable(phase) then
          choice_spec.meta = choice_spec.meta or {}
          choice_spec.meta.item_id = choice_spec.meta.item_id or item_id
          choice_spec.meta.player_id = choice_spec.meta.player_id or player.id
          item_phase.decorate_followup_choice_spec(choice_spec, meta)
        else
          assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
          item_preconsume_policy.decorate_followup_choice_spec(choice_spec, {
            item_id = item_id,
            player_id = player.id,
          })
        end
      end
      intent_output_port.dispatch(game, intent)
      return { stay = true }
    end
    return complete.phase_completion(game, player, meta, result)
  end

  local function _handle_item_phase_passive(game, choice, action)
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local item_id = action.option_id

    local result = use_item(game, player, item_id)
    assert(result ~= nil, "missing use_item result")
    if type(result) == "table" and result.waiting then
      local intent = result.intent or {}
      local choice_spec = intent.choice_spec
      if type(choice_spec) == "table" then
        choice_spec.meta = choice_spec.meta or {}
        choice_spec.meta.item_id = choice_spec.meta.item_id or item_id
        choice_spec.meta.player_id = choice_spec.meta.player_id or player.id
        choice_spec.meta.passive_origin = true
        item_phase.decorate_followup_choice_spec(choice_spec, meta)
      end
      intent_output_port.dispatch(game, intent)
      return { stay = true }
    end

    availability.mark_effect_group_used(game, item_id)
    local reopened = item_phase.reopen_or_finish(game, player, meta)
    return reopened and { stay = true } or nil
  end

  local function _item_phase_handler(kind, execute_fn)
    return {
      required_meta = { "player_id", "phase" },
      cancel = {
        resolve = function(game, choice)
          item_phase.finish(game, choice.meta and choice.meta.phase or nil)
        end,
      },
      normalize_meta = normalize.item_phase_meta,
      meta_validator = normalize.validate_item_phase_meta,
      normalize_action = function(_, _, action)
        return normalize.choice_action_option_id(kind, action)
      end,
      execute = execute_fn,
    }
  end

  return {
    item_phase_choice = _item_phase_handler("item_phase_choice", _handle_item_phase_choice),
    item_phase_passive = _item_phase_handler("item_phase_passive", _handle_item_phase_passive),
  }
end

local function _build_demolish_handlers(helpers)
  local complete = completions.build(helpers)

  local function _handle(game, choice, action)
    local index = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    normalize.consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = demolish.apply(game, player, index, {
      injure = meta.injure,
      title = meta.title,
      item_id = meta.item_id,
    })
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
    end
    local intent = result.intent or {}
    intent_output_port.dispatch(game, intent)
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    demolish_target = completions.item_target_handler("demolish_target", _handle, complete),
  }
end

local function _build_roadblock_handlers(helpers)
  local complete = completions.build(helpers)

  local function _handle(game, choice, action)
    local index = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    if not roadblock.is_ui_candidate(game, player, index) then
      logger.warn(player.name .. " 选择了无效的路障位置: " .. tostring(index))
      return { stay = true }
    end
    normalize.consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = roadblock.apply(game, player, index)
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
      intent_output_port.dispatch(game, result)
    end
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    roadblock_target = completions.item_target_handler("roadblock_target", _handle, complete),
  }
end

local function _build_target_player_handlers(helpers)
  local complete = completions.build(helpers)
  local use_item = helpers.use_item

  local function _handle(game, choice, action)
    local target_id = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local item_id = meta.item_id
    local result = use_item(game, player, item_id, {
      target_id = target_id,
      item_preconsumed = meta.item_preconsumed == true,
    })
    assert(result ~= nil, "missing use_item result")
    if result.waiting then
      return { stay = true }
    end
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    item_target_player = completions.item_target_handler("item_target_player", _handle, complete),
  }
end

local function _build_remote_dice_handlers(helpers)
  local complete = completions.build(helpers)

  local function _handle(game, choice, action)
    local value = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local dice_count = meta.dice_count or game:player_dice_count(player)
    normalize.consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = remote_dice.apply(game, player, dice_count, value)
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
    end
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    remote_dice_value = completions.item_target_handler("remote_dice_value", _handle, complete, {
      normalize_meta = normalize.remote_dice_meta,
      meta_validator = normalize.validate_remote_dice_meta,
    }),
  }
end

local M = {}

local _handler_builders = {
  _build_phase_handlers,
  _build_demolish_handlers,
  _build_roadblock_handlers,
  _build_target_player_handlers,
  _build_remote_dice_handlers,
}

function M.register(registry, helpers)
  for _, builder in ipairs(_handler_builders) do
    local handlers = builder(helpers)
    for kind, handler in pairs(handlers) do
      registry[kind] = handler
    end
  end
end

return M
