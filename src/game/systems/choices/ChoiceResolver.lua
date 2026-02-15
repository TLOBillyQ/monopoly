local logger = require("src.core.Logger")
local executor = require("src.game.systems.items.ItemExecutor")
local item_phase = require("src.game.systems.items.ItemPhase")
local effect = require("src.game.systems.effects.Effect")
local landing_defs = require("Config.LandingEffects")

local choice_resolver = {}

local function _is_cancel(action)
  return action ~= nil and action.type == "choice_cancel"
end

local function _clear_choice(game)
  game.turn.pending_choice = nil
  game.dirty.turn = true
  game.dirty.any = true
end

local function _use_item(game, player, item_id, context)
  return executor.use_item(game, player, item_id, context or {})
end

local function _finish_choice(game, stay)
  _clear_choice(game)
  return { status = stay and "waiting" or "resolved", stay = stay }
end

local function _contains(list, value)
  if type(list) ~= "table" then return false end
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function _option_exists(choice, option_id)
  if not choice or not option_id then return false end
  local options = choice.options
  if type(options) ~= "table" then return false end
  for _, opt in ipairs(options) do
    local id = opt
    if type(opt) == "table" then
      id = opt.id
    end
    if type(id) ~= "nil" and (id == option_id or tostring(id) == tostring(option_id)) then
      return true
    end
  end
  return false
end

local function _build_game_ctx(game, move_result)
  return effect.build_game_ctx(game, move_result, {
    phase_default = "wait_choice",
    on_landing = true,
  })
end

local function _finish_item_phase(game, phase)
  item_phase.finish(game, phase)
end

local function _finish_active_item_phase(game)
  local phase = game.turn.item_phase_active
  if phase and phase ~= "" then
    item_phase.finish(game, phase)
  end
end

local function _get_container_defs_by_choice_kind(choice_kind)
  if choice_kind == "landing_optional_effect" or choice_kind == "land_optional_effect" then
    return landing_defs
  end
  return nil
end

local function _find_effect_by_id(effect_defs, effect_id)
  assert(effect_defs ~= nil, "missing effect defs")
  for _, eff in ipairs(effect_defs) do
    if eff.id == effect_id then
      return eff
    end
  end
  return nil
end

local helpers = {
  is_cancel = _is_cancel,
  clear_choice = _clear_choice,
  finish_choice = _finish_choice,
  use_item = _use_item,
  contains = _contains,
  build_game_ctx = _build_game_ctx,
  finish_item_phase = _finish_item_phase,
  finish_active_item_phase = _finish_active_item_phase,
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

  if _is_cancel(action) then
    if choice.kind == "item_phase_choice" then
      local phase = choice.meta.phase
      _finish_item_phase(game, phase)
    end
    _clear_choice(game)
    return { status = "resolved", stay = false }
  end

  if not _option_exists(choice, action.option_id) then
    logger.warn("invalid choice option:", tostring(choice.kind), tostring(action.option_id))
    return { status = "rejected", stay = true }
  end

  local registries = assert(game.registries, "missing game.registries")
  local choice_registry = assert(registries.choices, "missing choice registry")
  local handler = choice_registry.handlers[choice.kind]
  assert(handler ~= nil, "unknown choice kind: " .. tostring(choice.kind))
  local res = handler(game, choice, action)
  if res and res.stay then
    res.status = res.status or "waiting"
    return res
  end
  return res or { status = "resolved", stay = false }
end

return choice_resolver
