local logger = require("src.core.Logger")
local chance_registry = require("src.game.systems.chance.ChanceRegistry")
local monopoly_event = require("src.game.core.runtime.MonopolyEvents")

local chance_effects = {}

local function _emit_event(kind, payload)
  if TriggerCustomEvent then
    TriggerCustomEvent(kind, payload or {})
  end
end

function chance_effects.resolve(game, player, card, context)
  if card.negative and game:player_has_angel(player) then
    _emit_event(monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 有天使附身，负面机会卡无效",
    })
    return nil
  end

  local handler = chance_registry.handlers[card.effect]
  assert(handler ~= nil, "未知机会卡效果:" .. tostring(card.effect))

  return handler(game, player, card, context)
end

return chance_effects
