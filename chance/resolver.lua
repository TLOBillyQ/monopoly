local utils = require("chance.utils")

local chance_resolver = {}

local function emit_resolve_event(kind, payload)
  if TriggerCustomEvent then
    TriggerCustomEvent(kind, payload or {})
  end
end

function chance_resolver.resolve(game, player, card, context)
  if card.negative and game:player_has_angel(player) then
    emit_resolve_event(utils.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 有天使附身，负面机会卡无效",
    })
    return nil
  end

  local registries = assert(game.registries, "missing game.registries")
  local chance_reg = assert(registries.chances, "missing chance registry")
  local handler = chance_reg.handlers[card.effect]
  assert(handler ~= nil, "未知机会卡效果:" .. tostring(card.effect))

  return handler(game, player, card, context)
end

return chance_resolver
