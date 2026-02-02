local Logger = require("Components.Logger")
local ChoiceRegistry = require("Manager.ChoiceManager.Choice.ChoiceRegistry")
local Executor = require("Manager.ItemManager.Item.ItemExecutor")
local ItemPhase = require("Manager.ItemManager.Item.ItemPhase")
local Effect = require("Manager.EffectManager.Effect.Effect")
local LandingDefs = require("Config.LandingEffects")

local ChoiceService = {}

local function is_cancel(action)
  assert(action ~= nil, "missing action")
  return action.type == "choice_cancel"
end

local function clear_choice(game)
  game.store:set({ "turn", "pending_choice" }, nil)
end

local function use_item(game, player, item_id, context)
  assert(context ~= nil, "missing item context")
  context.services = game:get_services()
  return Executor.use_item(game, player, item_id, context)
end

local function finish_choice(game, stay)
  clear_choice(game)
  return { stay = stay }
end


local function contains(list, value)
  assert(type(list) == "table", "contains requires table")
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function option_exists(choice, option_id)
  assert(choice ~= nil, "missing choice")
  assert(option_id ~= nil, "missing option_id")
  local options = choice.options
  assert(type(options) == "table" and #options > 0, "missing choice options")
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

local function build_game_ctx(game, move_result)
  return Effect.build_game_ctx(game, move_result, {
    phase_default = "wait_choice",
    on_landing = true,
  })
end

local function finish_item_phase(game, phase)
  ItemPhase.finish(game, phase)
end

local function finish_active_item_phase(game)
  local phase = game.store:get({ "turn", "item_phase_active" })
  if phase ~= "" then
    ItemPhase.finish(game, phase)
  end
end

local function get_container_defs_by_choice_kind(choice_kind)
  if choice_kind == "landing_optional_effect" or choice_kind == "land_optional_effect" then
    return LandingDefs
  end
  return nil
end

local function find_effect_by_id(effect_defs, effect_id)
  assert(effect_defs ~= nil, "missing effect defs")
  for _, eff in ipairs(effect_defs) do
    if eff.id == effect_id then
      return eff
    end
  end
  return nil
end

local helpers = {
  is_cancel = is_cancel,
  clear_choice = clear_choice,
  finish_choice = finish_choice,
  use_item = use_item,
  contains = contains,
  build_game_ctx = build_game_ctx,
  finish_item_phase = finish_item_phase,
  finish_active_item_phase = finish_active_item_phase,
  get_container_defs_by_choice_kind = get_container_defs_by_choice_kind,
  find_effect_by_id = find_effect_by_id,
}

function ChoiceService.resolve(game, choice, action)
  ChoiceRegistry.register_defaults(helpers)
  assert(game ~= nil, "missing game")
  assert(choice ~= nil, "missing choice")
  assert(action ~= nil, "missing action")

  if is_cancel(action) then
    if choice.kind == "item_phase_choice" then
      local phase = choice.meta.phase
      finish_item_phase(game, phase)
    end
    clear_choice(game)
    return { stay = false }
  end

  if not option_exists(choice, action.option_id) then
    Logger.warn("invalid choice option:", tostring(choice.kind), tostring(action.option_id))
    clear_choice(game)
    return { stay = false }
  end

  local handler = ChoiceRegistry.handlers[choice.kind]
  assert(handler ~= nil, "unknown choice kind: " .. tostring(choice.kind))
  return handler(game, choice, action)
end

return ChoiceService


