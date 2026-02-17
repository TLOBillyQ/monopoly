local utils = require("chance.utils")

local move_effects = {}

function move_effects.register(registry)
  registry:register("move_backward", function(game, player, card)
    local res = utils.move_steps(game, player, -(card.steps or 0), {
      skip_steal_check = true,
      skip_market_check = true,
    })
    if res and res.move_result then
      res.move_result.allow_optional = true
    end
    return res
  end)

  registry:register("move_forward", function(game, player, card)
    return utils.move_steps(game, player, card.steps or 0)
  end)

  registry:register("forced_move", function(game, player, card, context)
    local from_index = player.position
    if card.destination_tile_id then
      local idx = game.board:index_of_tile_id(card.destination_tile_id)
      assert(idx ~= nil, "missing destination tile index: " .. tostring(card.destination_tile_id))
      game:update_player_position(player, idx)
      game:set_player_status(player, "move_dir", nil)
      utils.queue_move_effect(game, player, from_index, idx, nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end
    if card.destination == "hospital" then
      game:player_send_to_hospital(player)
      utils.queue_move_effect(game, player, from_index, player.position, nil)
    elseif card.destination == "mountain" then
      game:player_send_to_mountain(player)
      utils.queue_move_effect(game, player, from_index, player.position, nil)
    elseif card.destination == "tax" then
      local idx = game.board:find_first_by_type("tax")
      assert(idx ~= nil, "missing tax tile")
      game:update_player_position(player, idx)
      game:set_player_status(player, "move_dir", nil)
      utils.queue_move_effect(game, player, from_index, idx, nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    elseif card.destination == "market" then
      local idx = game.board:find_first_by_type("market")
      assert(idx ~= nil, "missing market tile")
      game:update_player_position(player, idx)
      game:set_player_status(player, "move_dir", nil)
      utils.queue_move_effect(game, player, from_index, idx, nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end
  end)
end

return move_effects
