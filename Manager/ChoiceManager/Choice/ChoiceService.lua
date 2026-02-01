local logger = require("Library.Monopoly.Logger")
local ChoiceRegistry = require("Manager.ChoiceManager.Choice.ChoiceRegistry")
local Executor = require("Manager.ItemManager.Item.ItemExecutor")
local ItemPhase = require("Manager.ItemManager.Item.ItemPhase")
local Effect = require("Manager.EffectManager.Effect.Effect")
local landing_effects = require("Config.LandingEffects")

local ChoiceService = {}

local function is_cancel(action)
  return not action or action.type == "choice_cancel" or action.option_id == nil
end

local function clear_choice(game)
  game.store:set({ "turn", "pending_choice" }, nil)
end

local function use_item(game, player, item_id, context)
  context = context or {}
  context.services = context.services or game:get_services()
  return Executor.use_item(game, player, item_id, context)
end

local function finish_choice(game, stay)
  clear_choice(game)
  return { stay = stay }
end


local function contains(list, value)
  if type(list) ~= "table" then
    return false
  end
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function option_exists(choice, option_id)
  if not choice or option_id == nil then
    return false
  end
  local options = choice.options
  if type(options) ~= "table" or #options == 0 then
    return true
  end
  for _, opt in ipairs(options) do
    local id = opt
    if type(opt) == "table" then
      id = opt.id
    end
    if id ~= nil and (id == option_id or tostring(id) == tostring(option_id)) then
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
  if phase then
    ItemPhase.finish(game, phase)
  end
end

local function get_container_defs_by_choice_kind(choice_kind)
  if choice_kind == "landing_optional_effect" or choice_kind == "land_optional_effect" then
    return landing_effects or {}
  end
  return nil
end

local function find_effect_by_id(effect_defs, effect_id)
  for _, eff in ipairs(effect_defs or {}) do
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
  if not game or not choice then
    return { stay = false }
  end

  if is_cancel(action) then
    if choice.kind == "item_phase_choice" then
      local phase = choice.meta and choice.meta.phase
      finish_item_phase(game, phase)
    end
    clear_choice(game)
    return { stay = false }
  end

  if action and action.option_id ~= nil and not option_exists(choice, action.option_id) then
    logger.warn("invalid choice option:", tostring(choice.kind), tostring(action.option_id))
    clear_choice(game)
    return { stay = false }
  end

  local handler = ChoiceRegistry.handlers[choice.kind]
  if not handler then
    logger.warn("unknown choice kind:", tostring(choice.kind))
    clear_choice(game)
    return { stay = false }
  end
  return handler(game, choice, action)
end

return ChoiceService
