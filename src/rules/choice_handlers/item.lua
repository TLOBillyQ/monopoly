local inventory = require("src.rules.items.inventory")
local demolish = require("src.rules.items.demolish")
local steal = require("src.rules.items.steal")
local roadblock = require("src.rules.items.roadblock")
local logger = require("src.core.utils.logger")
local remote_dice = require("src.rules.items.remote_dice")
local item_phase = require("src.rules.items.phase")
local availability = require("src.rules.items.availability")
local item_ids = require("src.config.gameplay.item_ids")
local number_utils = require("src.core.utils.number_utils")
local intent_output_port = require("src.rules.ports.intent_output")
local item_use_broadcast = require("src.rules.items.use_broadcast")
local item_preconsume_policy = require("src.core.choice.item_preconsume_policy")

local M = {}

local copy_table = availability.copy_table
local normalize_integer_field = availability.normalize_integer_field

local function _normalize_integer_list(values, field_name, choice_kind)
  assert(type(values) == "table", tostring(choice_kind) .. " requires table meta." .. tostring(field_name))
  local normalized = {}
  for index, value in ipairs(values) do
    normalized[index] = assert(
      number_utils.to_integer(value),
      tostring(choice_kind) .. " requires numeric meta." .. tostring(field_name) .. "[" .. tostring(index) .. "]"
    )
  end
  return normalized
end

local function _normalize_choice_action_option_id(choice_kind, action)
  local normalized_action = copy_table(action)
  normalize_integer_field(normalized_action, "option_id", choice_kind, "action", true)
  return normalized_action
end

local function _validate_item_player(game, choice_kind, meta)
  return assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
end

local function _validate_item_target(game, field_name, meta)
  return assert(game:find_player_by_id(meta[field_name]), "missing " .. tostring(field_name) .. ": " .. tostring(meta[field_name]))
end

local function _finish_item_phase_by_name(game, phase)
  if type(phase) ~= "string" or phase == "" then
    return
  end
  item_phase.finish(game, phase)
end

local function _merge_after_action_anim(result, final_res)
  if type(result) == "table" and type(result.after_action_anim) == "table" then
    final_res.after_action_anim = result.after_action_anim
  end
  return final_res
end

local function _is_repeatable_phase_meta(meta)
  return type(meta) == "table" and item_phase.is_repeatable(meta.phase)
end

local function _consume_if_needed(player, item_id, already_consumed)
  if not item_id or already_consumed == true then
    return
  end
  assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
end

local function _open_steal_item_choice(game, stealer, target)
  local lines = {}
  local options = {}
  for index, item in ipairs(inventory.items(target)) do
    local label = inventory.item_name(item.id)
    table.insert(lines, index .. ". " .. label)
    table.insert(options, { id = index, label = label })
  end
  intent_output_port.open_choice(game, {
    kind = "steal_item",
    route_key = "player",
    owner_role_id = stealer.id,
    title = "选择要偷的道具",
    body_lines = lines,
    options = options,
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = stealer.id, target_id = target.id },
  })
end

local function _resolve_followup_cancel(game, choice)
  local meta = choice and choice.meta or nil
  if _is_repeatable_phase_meta(meta) then
    if meta.phase == "pre_action" then
      local player = _validate_item_player(game, choice.kind, meta)
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

local function _normalize_owner_meta(choice_kind, meta, choice_spec)
  local normalized_meta = copy_table(meta)
  normalize_integer_field(normalized_meta, "player_id", choice_kind)
  choice_spec.owner_role_id = choice_spec.owner_role_id or normalized_meta.player_id
  return normalized_meta
end

local function _normalize_target_picker_meta(choice_kind, meta, choice_spec)
  local normalized_meta = _normalize_owner_meta(choice_kind, meta, choice_spec)
  normalize_integer_field(normalized_meta, "item_id", choice_kind)
  choice_spec.target_picker_owner_role_id = choice_spec.target_picker_owner_role_id or normalized_meta.player_id
  return normalized_meta
end

local function _normalize_item_phase_meta(_, meta, choice_spec)
  local normalized_meta = _normalize_owner_meta(choice_spec.kind, meta, choice_spec)
  assert(type(normalized_meta.phase) == "string" and normalized_meta.phase ~= "",
    tostring(choice_spec.kind) .. " requires string meta.phase")
  return normalized_meta
end

local function _validate_item_phase_meta(game, meta, choice_spec)
  _validate_item_player(game, choice_spec.kind, meta)
  assert(item_phase.is_enabled(meta.phase), tostring(choice_spec.kind) .. " requires enabled meta.phase")
end

local function _validate_item_owner_meta(game, meta, choice_spec)
  _validate_item_player(game, choice_spec.kind, meta)
end

local function _normalize_steal_meta(_, meta, choice_spec)
  local normalized_meta = _normalize_owner_meta(choice_spec.kind, meta, choice_spec)
  normalize_integer_field(normalized_meta, "target_id", choice_spec.kind)
  return normalized_meta
end

local function _validate_steal_meta(game, meta, choice_spec)
  _validate_item_player(game, choice_spec.kind, meta)
  _validate_item_target(game, "target_id", meta)
end

local function _normalize_steal_prompt_meta(_, meta, choice_spec)
  local normalized_meta = _normalize_steal_meta(nil, meta, choice_spec)
  normalized_meta.queue = _normalize_integer_list(normalized_meta.queue, "queue", choice_spec.kind)
  normalize_integer_field(normalized_meta, "index", choice_spec.kind)
  return normalized_meta
end

local function _validate_steal_prompt_meta(game, meta, choice_spec)
  _validate_steal_meta(game, meta, choice_spec)
  assert(meta.queue[meta.index] ~= nil, tostring(choice_spec.kind) .. " requires meta.queue[meta.index]")
end

local function _normalize_item_target_meta(_, meta, choice_spec)
  local normalized_meta = _normalize_owner_meta(choice_spec.kind, meta, choice_spec)
  normalize_integer_field(normalized_meta, "item_id", choice_spec.kind)
  return normalized_meta
end

local function _normalize_remote_dice_meta(_, meta, choice_spec)
  local normalized_meta = _normalize_item_target_meta(nil, meta, choice_spec)
  normalize_integer_field(normalized_meta, "dice_count", choice_spec.kind)
  return normalized_meta
end

local function _validate_remote_dice_meta(game, meta, choice_spec)
  _validate_item_owner_meta(game, meta, choice_spec)
  if meta.dice_count ~= nil then
    assert(meta.dice_count >= 1, tostring(choice_spec.kind) .. " requires positive meta.dice_count")
  end
end

local function _build(helpers)
  local finish_choice = helpers.finish_choice
  local use_item = helpers.use_item

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
    if not _is_repeatable_phase_meta(meta) then
      _finish_item_phase_by_name(game, meta and meta.phase or nil)
      return _merge_after_action_anim(result, finish_choice(game, false))
    end
    if meta.phase == "post_action" then
      return _merge_after_action_anim(result, finish_choice(game, false))
    end
    local resumed = _resume_pre_action_phase(game, player, meta)
    if resumed.stay then
      return resumed
    end
    return _merge_after_action_anim(result, resumed)
  end

  local function _resolve_followup_completion(game, choice, player, result)
    local meta = choice.meta or {}
    if meta.passive_origin and meta.item_id then
      availability.mark_effect_group_used(game, meta.item_id)
    end
    if _is_repeatable_phase_meta(meta) then
      return _resolve_phase_completion(game, player, meta, result)
    end
    return _merge_after_action_anim(result, _finish_followup_choice(game))
  end

  local function _handle_demolish_target(game, choice, action)
    local index = action.option_id
    local meta = choice.meta
    local player = _validate_item_player(game, choice.kind, meta)
    _consume_if_needed(player, meta.item_id, meta.item_preconsumed)
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
    return _resolve_followup_completion(game, choice, player, result)
  end

  local function _handle_roadblock_target(game, choice, action)
    local index = action.option_id
    local meta = choice.meta
    local player = _validate_item_player(game, choice.kind, meta)
    if not roadblock.is_ui_candidate(game, player, index) then
      logger.warn(player.name .. " 选择了无效的路障位置: " .. tostring(index))
      return { stay = true }
    end
    _consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = roadblock.apply(game, player, index)
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
      intent_output_port.dispatch(game, result)
    end
    return _resolve_followup_completion(game, choice, player, result)
  end

  local function _handle_steal_item(game, choice, action)
    local index = action.option_id
    local meta = choice.meta
    local stealer = _validate_item_player(game, choice.kind, meta)
    local target = _validate_item_target(game, "target_id", meta)
    local result = steal.steal_item_at_index(game, stealer, target, index)
    if result == nil then
      logger.warn("steal_item resolved nil result:", tostring(index), tostring(target and target.id))
      return _resolve_followup_completion(game, choice, stealer, result)
    end
    intent_output_port.dispatch(game, result.intent or {})
    return _resolve_followup_completion(game, choice, stealer, result)
  end

  local function _handle_steal_prompt(game, choice, action)
    local meta = choice.meta
    local stealer = _validate_item_player(game, choice.kind, meta)
    local target = _validate_item_target(game, "target_id", meta)
    if target.eliminated then
      return finish_choice(game, false)
    end

    if action.option_id == "use" then
      if inventory.count(target) <= 1 then
        local result = steal.steal_item_at_index(game, stealer, target, 1)
        if result then
          intent_output_port.dispatch(game, result.intent or {})
        end
        return finish_choice(game, false)
      end
      _open_steal_item_choice(game, stealer, target)
      return { stay = true }
    end

    local next_index = meta.index + 1
    local queue = meta.queue
    if inventory.find_index(stealer, item_ids.steal) and queue[next_index] then
      local spec = steal.build_prompt_spec(game, stealer, queue, next_index)
      assert(spec ~= nil, "missing steal prompt spec")
      intent_output_port.open_choice(game, spec)
      return { stay = true }
    end

    return finish_choice(game, false)
  end

  local function _handle_item_target_player(game, choice, action)
    local target_id = action.option_id
    local meta = choice.meta
    local player = _validate_item_player(game, choice.kind, meta)
    local item_id = meta.item_id
    local result = use_item(game, player, item_id, {
      target_id = target_id,
      item_preconsumed = meta.item_preconsumed == true,
    })
    assert(result ~= nil, "missing use_item result")
    if result.waiting then
      return { stay = true }
    end
    return _resolve_followup_completion(game, choice, player, result)
  end

  local function _handle_remote_dice_value(game, choice, action)
    local value = action.option_id
    local meta = choice.meta
    local player = _validate_item_player(game, choice.kind, meta)
    local dice_count = meta.dice_count or game:player_dice_count(player)
    _consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = remote_dice.apply(game, player, dice_count, value)
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
    end
    return _resolve_followup_completion(game, choice, player, result)
  end

  local function _handle_item_phase_choice(game, choice, action)
    local meta = choice.meta
    local player = _validate_item_player(game, choice.kind, meta)
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
    return _resolve_phase_completion(game, player, meta, result)
  end

  local function _handle_item_phase_passive(game, choice, action)
    local meta = choice.meta
    local player = _validate_item_player(game, choice.kind, meta)
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
    local reopened = item_phase.reopen_passive_or_finish(game, player, meta)
    return reopened and { stay = true } or nil
  end

  return {
    item_phase_choice = {
      required_meta = { "player_id", "phase" },
      cancel = {
        resolve = function(game, choice)
          item_phase.finish(game, choice.meta and choice.meta.phase or nil)
        end,
      },
      normalize_meta = _normalize_item_phase_meta,
      meta_validator = _validate_item_phase_meta,
      normalize_action = function(_, _, action)
        return _normalize_choice_action_option_id("item_phase_choice", action)
      end,
      execute = _handle_item_phase_choice,
    },
    item_phase_passive = {
      required_meta = { "player_id", "phase" },
      cancel = {
        resolve = function(game, choice)
          item_phase.finish(game, choice.meta and choice.meta.phase or nil)
        end,
      },
      normalize_meta = _normalize_item_phase_meta,
      meta_validator = _validate_item_phase_meta,
      normalize_action = function(_, _, action)
        return _normalize_choice_action_option_id("item_phase_passive", action)
      end,
      execute = _handle_item_phase_passive,
    },
    demolish_target = {
      required_meta = { "player_id", "item_id" },
      cancel = {
        resolve = function(game, choice)
          return _resolve_followup_cancel(game, choice)
        end,
      },
      normalize_meta = _normalize_item_target_meta,
      meta_validator = _validate_item_owner_meta,
      normalize_action = function(_, _, action)
        return _normalize_choice_action_option_id("demolish_target", action)
      end,
      execute = _handle_demolish_target,
    },
    roadblock_target = {
      required_meta = { "player_id", "item_id" },
      cancel = {
        resolve = function(game, choice)
          return _resolve_followup_cancel(game, choice)
        end,
      },
      normalize_meta = _normalize_target_picker_meta,
      meta_validator = _validate_item_owner_meta,
      normalize_action = function(_, _, action)
        return _normalize_choice_action_option_id("roadblock_target", action)
      end,
      execute = _handle_roadblock_target,
    },
    steal_item = {
      required_meta = { "player_id", "target_id" },
      cancel = {
        resolve = function(game, choice)
          return _resolve_followup_cancel(game, choice)
        end,
      },
      normalize_meta = _normalize_steal_meta,
      meta_validator = _validate_steal_meta,
      normalize_action = function(_, _, action)
        return _normalize_choice_action_option_id("steal_item", action)
      end,
      execute = _handle_steal_item,
    },
    steal_prompt = {
      required_meta = { "player_id", "target_id", "queue", "index" },
      cancel = { mode = "select_option", option_id = "skip" },
      normalize_meta = _normalize_steal_prompt_meta,
      meta_validator = _validate_steal_prompt_meta,
      execute = _handle_steal_prompt,
    },
    item_target_player = {
      required_meta = { "player_id", "item_id" },
      cancel = {
        resolve = function(game, choice)
          return _resolve_followup_cancel(game, choice)
        end,
      },
      normalize_meta = _normalize_item_target_meta,
      meta_validator = _validate_item_owner_meta,
      normalize_action = function(_, _, action)
        return _normalize_choice_action_option_id("item_target_player", action)
      end,
      execute = _handle_item_target_player,
    },
    remote_dice_value = {
      required_meta = { "player_id", "item_id" },
      cancel = {
        resolve = function(game, choice)
          return _resolve_followup_cancel(game, choice)
        end,
      },
      normalize_meta = _normalize_remote_dice_meta,
      meta_validator = _validate_remote_dice_meta,
      normalize_action = function(_, _, action)
        return _normalize_choice_action_option_id("remote_dice_value", action)
      end,
      execute = _handle_remote_dice_value,
    },
  }
end

function M.register(registry, helpers)
  local handlers = _build(helpers)
  for kind, handler in pairs(handlers) do
    registry[kind] = handler
  end
end

return M
