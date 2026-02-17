local utils = require("chance.utils")

local item_effects = {}

function item_effects.register(registry)
  registry:register("grant_item", function(game, player, card)
    utils.inventory.give(player, card.item_id, { game = game })
  end)

  registry:register("discard_items", function(game, player, card)
    local to_drop = card.count
    if to_drop == 0 then
      to_drop = utils.inventory.count(player)
    end
    local dropped_names = {}
    for _ = 1, to_drop do
      if utils.inventory.count(player) == 0 then
        break
      end
      local item = utils.inventory.remove_by_index(player, 1)
      table.insert(dropped_names, utils.inventory.item_name(item.id))
    end
    if #dropped_names > 0 then
      utils.emit_event(utils.monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 丢弃道具 " .. #dropped_names .. " 张: " .. table.concat(dropped_names, "、"),
      })
    else
      utils.emit_event(utils.monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 丢弃道具 0 张",
      })
    end
  end)
end

return item_effects
