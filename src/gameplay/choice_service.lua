local logger = require("src.util.logger")

local ChoiceService = {}
local deps = nil
local handler_registry = {}

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
  context.services = context.services or game:get_services()
  return deps.executor.use_item(game, player, item_id, context, {
    inventory = deps.inventory,
    strategy = deps.strategy,
  })
end

local function finish_choice(game, stay)
  clear_choice(game)
  return { stay = stay and true or false }
end

-- 选择处理约定：
-- 1) 下层若返回 { waiting = true, intent = ... }，由上层负责派发 intent 并保持等待。
-- 2) 处理器已派发 intent 时，只返回 { stay = true } 即可。
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

local function build_game_ctx(game, move_result)
  return deps.effect.build_game_ctx(game, move_result, {
    phase_default = "wait_choice",
    on_landing = true,
  })
end

local function finish_item_phase(game, phase)
  deps.item_phase.finish(game, phase)
end

local function finish_active_item_phase(game)
  if not (game and game.store) then
    return
  end
  local phase = game.store:get({ "turn", "item_phase_active" })
  if phase then
    deps.item_phase.finish(game, phase)
  end
end

local function get_container_defs_by_choice_kind(choice_kind)
  if choice_kind == "landing_optional_effect" or choice_kind == "land_optional_effect" then
    return deps.landing_effects or {}
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

function ChoiceService.register(kind, handler)
  handler_registry[kind] = handler
end

local function merge_handlers(list)
  for _, group in ipairs(list) do
    for key, handler in pairs(group) do
      ChoiceService.register(key, handler)
    end
  end
end

function ChoiceService.setup(in_deps)
  deps = in_deps or {}
  assert(deps.executor, "ChoiceService requires executor")
  assert(deps.inventory, "ChoiceService requires inventory")
  assert(deps.strategy, "ChoiceService requires strategy")
  assert(deps.item_phase, "ChoiceService requires item_phase")
  assert(deps.effect, "ChoiceService requires effect")
  assert(deps.landing_effects, "ChoiceService requires landing_effects")
  assert(deps.land_choice_handler, "ChoiceService requires land_choice_handler")
  assert(deps.market_choice_handler, "ChoiceService requires market_choice_handler")
  assert(deps.item_choice_handler, "ChoiceService requires item_choice_handler")
  assert(deps.optional_effect_handler, "ChoiceService requires optional_effect_handler")

  handler_registry = {}
  merge_handlers({
    deps.optional_effect_handler.build(helpers),
    deps.land_choice_handler.build(helpers),
    deps.item_choice_handler.build(helpers),
    deps.market_choice_handler.build(helpers),
  })
end

function ChoiceService.resolve(game, choice, action)
  assert(deps, "ChoiceService.setup must be called before resolve")
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

  local handler = handler_registry[choice.kind] or function(inner_game, inner_choice, inner_action)
    logger.warn("unknown choice kind:", tostring(choice.kind))
    clear_choice(inner_game)
    return { stay = false }
  end
  return handler(game, choice, action)
end

return ChoiceService
