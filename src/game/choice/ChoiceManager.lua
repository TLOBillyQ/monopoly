local Logger = require("src.core.Logger")
local ChoiceRegistry = require("src.game.choice.ChoiceRegistry")
local Executor = require("src.game.item.ItemExecutor")
local ItemPhase = require("src.game.item.ItemPhase")
local Effect = require("src.game.effect.Effect")
local LandingDefs = require("Config.LandingEffects")

local ChoiceManager = {}

local function _IsCancel(action)
  assert(action ~= nil, "missing action")
  return action.type == "choice_cancel"
end

local function _ClearChoice(game)
  game.store:Set({ "turn", "pending_choice" }, nil)
end

local function _UseItem(game, player, item_id, context)
  assert(context ~= nil, "missing item context")
  return Executor.UseItem(game, player, item_id, context)
end

local function _FinishChoice(game, stay)
  _ClearChoice(game)
  return { stay = stay }
end


local function _Contains(list, value)
  assert(type(list) == "table", "contains requires table")
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function _OptionExists(choice, option_id)
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

local function _BuildGameCtx(game, move_result)
  return Effect.BuildGameCtx(game, move_result, {
    phase_default = "wait_choice",
    on_landing = true,
  })
end

local function _FinishItemPhase(game, phase)
  ItemPhase.Finish(game, phase)
end

local function _FinishActiveItemPhase(game)
  local phase = game.store:Get({ "turn", "item_phase_active" })
  if phase ~= "" then
    ItemPhase.Finish(game, phase)
  end
end

local function _GetContainerDefsByChoiceKind(choice_kind)
  if choice_kind == "landing_optional_effect" or choice_kind == "land_optional_effect" then
    return LandingDefs
  end
  return nil
end

local function _FindEffectById(effect_defs, effect_id)
  assert(effect_defs ~= nil, "missing effect defs")
  for _, eff in ipairs(effect_defs) do
    if eff.id == effect_id then
      return eff
    end
  end
  return nil
end

local helpers = {
  IsCancel = _IsCancel,
  ClearChoice = _ClearChoice,
  FinishChoice = _FinishChoice,
  UseItem = _UseItem,
  Contains = _Contains,
  BuildGameCtx = _BuildGameCtx,
  FinishItemPhase = _FinishItemPhase,
  FinishActiveItemPhase = _FinishActiveItemPhase,
  GetContainerDefsByChoiceKind = _GetContainerDefsByChoiceKind,
  FindEffectById = _FindEffectById,
}

function ChoiceManager.Resolve(game, choice, action)
  ChoiceRegistry.RegisterDefaults(helpers)
  assert(game ~= nil, "missing game")
  assert(choice ~= nil, "missing choice")
  assert(action ~= nil, "missing action")

  if _IsCancel(action) then
    if choice.kind == "item_phase_choice" then
      local phase = choice.meta.phase
      _FinishItemPhase(game, phase)
    end
    _ClearChoice(game)
    return { stay = false }
  end

  if not _OptionExists(choice, action.option_id) then
    Logger.Warn("invalid choice option:", tostring(choice.kind), tostring(action.option_id))
    _ClearChoice(game)
    return { stay = false }
  end

  local handler = ChoiceRegistry.handlers[choice.kind]
  assert(handler ~= nil, "unknown choice kind: " .. tostring(choice.kind))
  return handler(game, choice, action)
end

return ChoiceManager

