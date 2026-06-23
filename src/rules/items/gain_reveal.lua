local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local action_anim_port = require("src.foundation.ports.action_anim")
local inventory = require("src.rules.items.inventory")

local gain_reveal = {}

function gain_reveal.queue(game, player, item_id, opts)
  if game == nil or player == nil or item_id == nil then
    return false
  end
  return action_anim_port.queue(game, {
    kind = event_kinds.item_get_reveal,
    player_id = player.id,
    owner_role_id = player.id,
    item_id = item_id,
    item_name = inventory.item_name(item_id),
    duration = timing.item_get_reveal_seconds,
    source = opts and opts.source or nil,
  })
end

return gain_reveal
