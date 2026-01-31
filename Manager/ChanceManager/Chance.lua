local logger = require("Library.Monopoly.Logger")
local ChanceRegistry = require("Manager.ChanceManager.ChanceRegistry")
local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

local ChanceEffects = {}

local function emit_event(kind, payload)
  if TriggerCustomEvent then
    TriggerCustomEvent(kind, payload or {})
  end
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

  local handler = ChanceRegistry.get(card.effect)
  if not handler then
    logger.warn("未知机会卡效果:" .. tostring(card.effect))
    return nil
  end

  return handler(game, player, card, context)
end

return ChanceEffects
