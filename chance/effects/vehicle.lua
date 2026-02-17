local utils = require("chance.utils")

local vehicle_effects = {}

function vehicle_effects.register(registry)
  registry:register("set_vehicle", function(game, player, card)
    if not utils.vehicle_feature.is_enabled() then
      return
    end
    game:set_player_seat(player, card.vehicle_id)
    local vehicle_name = utils.vehicle_name_by_id[card.vehicle_id] or tostring(card.vehicle_id)
    utils.emit_event(utils.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 获得座驾 " .. vehicle_name,
    })
  end)
end

return vehicle_effects
