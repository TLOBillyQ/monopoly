local Inventory = require("src.gameplay.item_inventory")
local Executor = require("src.gameplay.item_executor")
local Strategy = require("src.gameplay.item_strategy")
local ItemPhase = require("src.gameplay.item_phase")
local logger = require("src.util.logger")

local LandChoiceHandler = require("src.gameplay.choice_handlers.land_choice_handler")
local MarketChoiceHandler = require("src.gameplay.choice_handlers.market_choice_handler")
local ItemChoiceHandler = require("src.gameplay.choice_handlers.item_choice_handler")
local OptionalEffectHandler = require("src.gameplay.choice_handlers.optional_effect_handler")

local ChoiceService = {}

local function is_cancel(action)
  return not action or action.type == "choice_cancel" or action.option_id == nil
end

local function clear_choice(game)
  if not (game and game.store) then
    return
  end
  game.store:set({ "turn", "pending_choice" }, nil)
end

local function use_item(game, player, item_id, context)
  context = context or {}
  context.services = context.services or (game and game.services)
  return Executor.use_item(game, player, item_id, context, { inventory = Inventory, strategy = Strategy })
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
    local id = (type(opt) == "table") and opt.id or opt
    if id ~= nil and (id == option_id or tostring(id) == tostring(option_id)) then
      return true
    end
  end
  return false
end

local function build_effect_ctx(game, player, tile, move_result)
  local phase = game and game.store and game.store:get({ "turn", "phase" }) or "wait_choice"
  return {
    game = game,
    store = game and game.store,
    rng = game and game.rng,
    services = game and game.services,
    phase = phase,
    player = player,
    tile = tile,
    move_result = move_result,
    on_landing = true,
  }
end

local function finish_item_phase(game, phase)
  ItemPhase.finish(game, phase)
end

local function finish_active_item_phase(game)
  if not (game and game.store) then
    return
  end
  local phase = game.store:get({ "turn", "item_phase_active" })
  if phase then
    ItemPhase.finish(game, phase)
  end
end

local function get_container_defs_by_choice_kind(choice_kind)
  if choice_kind == "landing_optional_effect" or choice_kind == "land_optional_effect" then
    local landing_effects = require("src.gameplay.landing")
    return landing_effects and landing_effects.defs or {}
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
  use_item = use_item,
  contains = contains,
  build_effect_ctx = build_effect_ctx,
  finish_item_phase = finish_item_phase,
  finish_active_item_phase = finish_active_item_phase,
  get_container_defs_by_choice_kind = get_container_defs_by_choice_kind,
  find_effect_by_id = find_effect_by_id,
}

local handlers = {}

local function merge_handlers(list)
  for _, group in ipairs(list) do
    for key, handler in pairs(group) do
      handlers[key] = handler
    end
  end
end

merge_handlers({
  OptionalEffectHandler.build(helpers),
  LandChoiceHandler.build(helpers),
  ItemChoiceHandler.build(helpers),
  MarketChoiceHandler.build(helpers),
})

function ChoiceService.resolve(game, choice, action)
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

  local handler = handlers[choice.kind] or function(inner_game, inner_choice, inner_action)
    logger.warn("unknown choice kind:", tostring(choice.kind))
    clear_choice(inner_game)
    return { stay = false }
  end
  return handler(game, choice, action)
end

return ChoiceService
