local logger = require("core.logger")
local game_event = require("game.event")
local gameplay_rules = require("cfg.GameplayRules")

local mine = {}
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

function mine.apply(game, player, position)
  assert(game ~= nil, "missing game")
  local board = assert(game.board, "missing board")
  assert(player ~= nil, "missing player")
  assert(position ~= nil, "missing position")

  if game:player_has_angel(player) then
    logger.event(player.name .. " 天使保护，地雷无效")
    board:clear_mine(position)
    return { detonated = true, protected = true }
  end

  board:clear_mine(position)
  if TriggerCustomEvent and game_event and game_event.land and game_event.land.mine_hit then
    local tile_obj = board:get_tile(position)
    TriggerCustomEvent(game_event.land.mine_hit, {
      player = player,
      tile_id = tile_obj and tile_obj.id or nil,
      tile_index = position,
    })
  end
  if game:player_is_vehicle_indestructible(player) then
    logger.event(player.name .. " 座驾免疫地雷")
    return { detonated = true, protected = true }
  end
  game:set_player_seat(player, nil)
  logger.event(player.name .. " 触发地雷，座驾被摧毁并送医")
  local from_index = position
  game:player_send_to_hospital(player)
  local ui_port = game.ui_port
  if ui_port and ui_port.wait_action_anim then
    game:queue_action_anim({
      kind = "move_effect",
      player_id = player.id,
      from_index = from_index,
      to_index = player.position,
      duration = action_anim_duration,
    })
  end
  return { detonated = true, hospitalized = true, new_position = player.position }
end

return mine
