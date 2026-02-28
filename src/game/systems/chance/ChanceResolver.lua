local monopoly_event = require("src.game.core.runtime.MonopolyEvents")

local chance_resolver = {}

function chance_resolver.resolve(game, player, card, context)
  if card.negative and game:player_has_angel(player) then
    monopoly_event.emit(monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 有天使附身，负面机会卡无效",
    })
    return nil
  end

  local registries = assert(game.registries, "missing game.registries")
  local chance_handlers = assert(registries.chances, "missing chance handlers")
  local handler = chance_handlers[card.effect]
  assert(handler ~= nil, "未知机会卡效果:" .. tostring(card.effect))

  return handler(game, player, card, context)
end

return chance_resolver
