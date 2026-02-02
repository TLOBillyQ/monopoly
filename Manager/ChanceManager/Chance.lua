local Logger = require("Components.Logger")
local ChanceRegistry = require("Manager.ChanceManager.ChanceRegistry")
local MonopolyEvent = require("Globals.MonopolyEvents")

local ChanceEffects = {}

local function _EmitEvent(kind, payload)
  assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
  TriggerCustomEvent(kind, payload or {})
end

function ChanceEffects.Resolve(game, player, card, context)
  if card.negative and player:HasAngel() then
    _EmitEvent(MonopolyEvent.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 有天使附身，负面机会卡无效",
    })
    return nil
  end

  local handler = ChanceRegistry.handlers[card.effect]
  assert(handler ~= nil, "未知机会卡效果:" .. tostring(card.effect))

  return handler(game, player, card, context)
end

return ChanceEffects


