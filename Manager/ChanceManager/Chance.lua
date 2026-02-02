local logger = require("Components.Logger")
local ChanceRegistry = require("Manager.ChanceManager.ChanceRegistry")
local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

local ChanceEffects = {}

local function emit_event(kind, payload)
  assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
  TriggerCustomEvent(kind, payload or {})
end

function ChanceEffects.resolve(game, player, card, context)
  if card.negative and player:has_angel() then
    emit_event(MONOPOLY_EVENT.chance.applied, {
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


