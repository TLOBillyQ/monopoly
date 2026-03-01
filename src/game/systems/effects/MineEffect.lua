local logger = require("src.core.Logger")
local monopoly_event = require("src.core.events.MonopolyEvents")
local gameplay_rules = require("Config.GameplayRules")
local action_anim_port = require("src.core.ActionAnimPort")

local mine_effect = {}
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

function mine_effect.apply(game, player, position)
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
  if monopoly_event and monopoly_event.land and monopoly_event.land.mine_hit then
    local tile = board:get_tile(position)
    monopoly_event.emit(monopoly_event.land.mine_hit, {
      player = player,
      tile_id = tile and tile.id or nil,
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
  action_anim_port.queue(game, {
    kind = "move_effect",
    player_id = player.id,
    from_index = from_index,
    to_index = player.position,
    duration = action_anim_duration,
  })
  return { detonated = true, hospitalized = true, new_position = player.position }
end

return mine_effect

