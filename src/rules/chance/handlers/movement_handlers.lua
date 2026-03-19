local movement_handlers = {}
local market_default_move_dir = "right"

function movement_handlers.register(handlers, common)
  handlers.move_backward = function(game, player, card)
    local res = common.move_steps(game, player, -(card.steps or 0), {
      facing_mode = "relative_backward",
      skip_steal_check = true,
      skip_market_check = true,
    })
    if res and res.move_result then
      res.move_result.allow_optional = true
    end
    return res
  end

  handlers.move_forward = function(game, player, card)
    return common.move_steps(game, player, card.steps or 0)
  end

  handlers.forced_move = function(game, player, card, context)
    local from_index = player.position
    local function _build_location_followup(effect_name)
      return {
        waiting = true,
        wait_action_anim = true,
        next_state = "move_followup",
        next_args = {
          mode = "apply_location_effects",
          effects = {
            { player_id = player.id, effect = effect_name },
          },
          next_state = "post_action",
          next_args = { player = player },
        },
      }
    end
    if card.destination_tile_id then
      local idx = game.board:index_of_tile_id(card.destination_tile_id)
      assert(idx ~= nil, "missing destination tile index: " .. tostring(card.destination_tile_id))
      game:update_player_position(player, idx)
      common.queue_move_effect(game, player, from_index, idx, nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end

    if card.destination == "hospital" then
      local idx = game.board:find_first_by_type("hospital")
      assert(idx ~= nil, "missing hospital tile")
      game:update_player_position(player, idx)
      game:set_player_status(player, "move_dir", nil)
      common.queue_move_effect(game, player, from_index, idx, nil)
      return _build_location_followup("hospital")
    end

    if card.destination == "mountain" then
      local idx = game.board:find_first_by_type("mountain")
      assert(idx ~= nil, "missing mountain tile")
      game:update_player_position(player, idx)
      game:set_player_status(player, "move_dir", nil)
      common.queue_move_effect(game, player, from_index, idx, nil)
      return _build_location_followup("mountain")
    end

    local type_by_destination = {
      tax = "tax",
      market = "market",
    }
    local tile_type = type_by_destination[card.destination]
    if not tile_type then
      return
    end

    local idx = game.board:find_first_by_type(tile_type)
    assert(idx ~= nil, "missing " .. tile_type .. " tile")
    game:update_player_position(player, idx)
    if tile_type == "market" then
      game:set_player_status(player, "move_dir", market_default_move_dir)
    end
    common.queue_move_effect(game, player, from_index, idx, nil)
    return {
      kind = "need_landing",
      player_id = player.id,
      board_index = idx,
      move_result = context,
    }
  end
end

return movement_handlers
