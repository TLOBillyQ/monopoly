local logger = require("src.core.utils.logger")
local gameplay_rules = require("src.config.gameplay.rules")
local action_anim_port = require("src.core.ports.action_anim")

local mine_effect = {}
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

local function _build_trigger_log_entry(player, had_vehicle)
  if had_vehicle == true then
    return player.name .. " 触发地雷，座驾被摧毁并送医"
  end
  return player.name .. " 触发地雷并送医"
end

function mine_effect.can_trigger(game, player, position)
  local board = game and game.board or nil
  if not (board and position and board:has_mine(position)) then
    return false
  end

  local mine = board:get_mine(position)
  if type(mine) ~= "table" then
    return true
  end
  if mine.armed ~= true then
    return false
  end

  local turn = game and game.turn or nil
  if player and mine.owner_id == player.id and mine.placed_turn_count ~= nil
      and turn and mine.placed_turn_count == turn.turn_count then
    return false
  end
  return true
end

function mine_effect.apply(game, player, position)
  assert(game ~= nil, "missing game")
  local board = assert(game.board, "missing board")
  assert(player ~= nil, "missing player")
  assert(position ~= nil, "missing position")

  if game:player_has_angel(player) then
    logger.event(player.name .. " 天使保护，地雷无效")
    game:clear_mine(position)
    return { detonated = true, protected = true }
  end

  game:clear_mine(position)
  if game:player_is_vehicle_indestructible(player) then
    logger.event(player.name .. " 座驾免疫地雷")
    return { detonated = true, protected = true }
  end
  local from_index = position
  local had_vehicle = player.seat_id ~= nil
  local hospital_index = game:player_relocate(player, {
    tile_type = "hospital",
    clear_seat = true,
    move_dir_mode = "clear",
  })
  game:set_player_status(player, "pending_location_effect", "hospital")
  action_anim_port.queue(game, {
    kind = "mine_trigger",
    player_id = player.id,
    tile_index = position,
    from_index = from_index,
    to_index = hospital_index,
    duration = action_anim_duration,
    cue_name = "mine_blast",
  })
  return {
    detonated = true,
    hospitalized = true,
    new_position = hospital_index,
    wait_action_anim = true,
    next_state = "move_followup",
    next_args = {
      mode = "apply_location_effects",
      log_entries = {
        _build_trigger_log_entry(player, had_vehicle),
      },
      effects = {
        { player_id = player.id, effect = "hospital" },
      },
      next_state = "end_turn",
      next_args = { player = player },
    },
  }
end

return mine_effect
