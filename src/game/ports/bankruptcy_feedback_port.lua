local bankruptcy_feedback_port = {}
local contract_helper = require("src.game.ports.contract_helper")

function bankruptcy_feedback_port.on_tiles_cleared(game, player, owned_tile_ids)
  return contract_helper.call_required_method(game, "bankruptcy_feedback_port", "bankruptcy_feedback_port", "on_tiles_cleared", game, player, owned_tile_ids)
end

return bankruptcy_feedback_port
