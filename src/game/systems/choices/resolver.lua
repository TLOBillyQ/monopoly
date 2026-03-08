local logger = require("src.core.utils.logger")
local executor = require("src.game.systems.items.executor")
local item_phase = require("src.game.systems.items.phase")
local effect_runner = require("src.game.systems.effects.effect_runner")
local landing_defs = require("src.game.systems.land.specs.effects")

local choice_resolver = {}

local cancel_result_by_mode = {
  finish_item_phase = function(game, choice)
    item_phase.finish(game, choice.meta and choice.meta.phase or nil)
  end,
  finish_active_item_phase = function(game)
    local phase = game.turn.item_phase_active
    if phase and phase ~= "" then
      item_phase.finish(game, phase)
    end
  end,
}

local function _each_option(choice, visitor)
  local options = choice and choice.options or nil
  if type(options) ~= "table" then
    return nil
  end
  for index, option in ipairs(options) do
    local option_id = type(option) == "table" and option.id or option
    local result = visitor(option, option_id, index)
    if result ~= nil then
      return result
    end
  end
  return nil
end

local function _is_cancel(action)
  return action ~= nil and action.type == "choice_cancel"
end

local function _first_option_id(choice)
  return _each_option(choice, function(_, option_id)
    return option_id
  end)
end

local function _find_option_id(choice, target_option_id)
  return _each_option(choice, function(_, option_id)
    if option_id == target_option_id then
      return option_id
    end
  end)
end

local function _choice_title(choice)
  if choice and choice.title and choice.title ~= "" then
    return choice.title
  end
  return "请选择"
end

local function _clear_choice(game)
  game.turn.pending_choice = nil
  game.dirty.turn = true
  game.dirty.any = true
end

local function _finish_choice(game, stay)
  _clear_choice(game)
  return { status = stay and "waiting" or "resolved", stay = stay }
end

local function _contains(list, value)
  if type(list) ~= "table" then
    return false
  end
  for _, current_value in ipairs(list) do
    if current_value == value then
      return true
    end
  end
  return false
end

local function _option_exists(choice, target_option_id)
  if choice == nil or target_option_id == nil then
    return false
  end
  return _each_option(choice, function(_, option_id)
    if option_id == target_option_id or tostring(option_id) == tostring(target_option_id) then
      return true
    end
  end) == true
end

local function _build_game_ctx(game, move_result)
  return effect_runner.build_game_ctx(game, move_result, {
    phase_default = "wait_choice",
    on_landing = true,
  })
end

local function _get_container_defs_by_choice_kind(choice_kind)
  if choice_kind == "landing_optional_effect" then
    return landing_defs
  end
  return nil
end

local function _find_effect_by_id(effect_defs, effect_id)
  assert(effect_defs ~= nil, "missing effect defs")
  for _, effect_definition in ipairs(effect_defs) do
    if effect_definition.id == effect_id then
      return effect_definition
    end
  end
  return nil
end

local function _build_select_action(choice, option_id, action)
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = option_id,
    actor_role_id = action and action.actor_role_id or nil,
  }
end

local function _resolve_descriptor(game, choice)
  local registries = assert(game.registries, "missing game.registries")
  local choice_registry = assert(registries.choices, "missing choice registry")
  local descriptor = type(choice_registry.descriptor_for) == "function"
      and choice_registry:descriptor_for(choice.kind)
      or choice_registry.handlers[choice.kind]
  assert(descriptor ~= nil, "unknown choice kind: " .. tostring(choice.kind))
  assert(type(descriptor.execute) == "function", "invalid choice descriptor: " .. tostring(choice.kind))
  return descriptor
end

local function _resolve_cancel_followup(game, choice, descriptor)
  local cancel = descriptor and descriptor.cancel or nil
  if type(cancel) ~= "table" then
    return nil, nil
  end
  if cancel.mode == "select_option" then
    return _find_option_id(choice, cancel.option_id), nil
  end
  return nil, cancel_result_by_mode[cancel.mode]
end

local helpers = {
  is_cancel = _is_cancel,
  clear_choice = _clear_choice,
  finish_choice = _finish_choice,
  use_item = executor.use_item,
  contains = _contains,
  build_game_ctx = _build_game_ctx,
  finish_item_phase = cancel_result_by_mode.finish_item_phase,
  finish_active_item_phase = cancel_result_by_mode.finish_active_item_phase,
  get_container_defs_by_choice_kind = _get_container_defs_by_choice_kind,
  find_effect_by_id = _find_effect_by_id,
}

function choice_resolver.helpers()
  local out = {}
  for key, value in pairs(helpers) do
    out[key] = value
  end
  return setmetatable(out, {
    __newindex = function()
      error("helpers is read-only")
    end,
    __metatable = false,
  })
end

function choice_resolver.resolve(game, choice, action)
  assert(game ~= nil, "missing game")
  assert(choice ~= nil, "missing choice")
  assert(action ~= nil, "missing action")

  local descriptor = _resolve_descriptor(game, choice)

  if _is_cancel(action) and choice.meta and choice.meta.item_preconsumed == true then
    local fallback_option_id = _first_option_id(choice)
    if fallback_option_id ~= nil then
      action = _build_select_action(choice, fallback_option_id, action)
    end
  end

  if _is_cancel(action) then
    local fallback_option_id, cancel_result = _resolve_cancel_followup(game, choice, descriptor)
    if fallback_option_id ~= nil then
      action = _build_select_action(choice, fallback_option_id, action)
    else
      if type(cancel_result) == "function" then
        cancel_result(game, choice)
      end
      logger.event_no_tips("跳过选择：" .. _choice_title(choice))
      _clear_choice(game)
      return { status = "resolved", stay = false }
    end
  end

  if descriptor.normalize_action ~= nil then
    local normalized_action = descriptor.normalize_action(game, choice, action)
    if normalized_action ~= nil then
      action = normalized_action
    end
  end

  if not _option_exists(choice, action.option_id) then
    logger.warn("invalid choice option:", tostring(choice.kind), tostring(action.option_id))
    return { status = "rejected", stay = true }
  end

  local result = descriptor.execute(game, choice, action)
  if result and result.stay then
    result.status = result.status or "waiting"
    return result
  end
  return result or { status = "resolved", stay = false }
end

return choice_resolver
