local logger = require("src.core.utils.logger")
local gameplay_rules = require("src.config.gameplay.rules")
local action_anim_port = require("src.core.ports.action_anim")

local mine_effect = {}
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

local function _build_obstacle_chain_key(game, player, position)
  local turn = game and game.turn or nil
  local turn_count = turn and turn.turn_count or 0
  return tostring(turn_count) .. ":" .. tostring(player.id) .. ":" .. tostring(position)
end

local function _find_pending_roadblock_trigger(game, player, position)
  if not (game and game.turn) then
    return nil
  end
  local current = game.turn.action_anim
  if current
      and current.kind == "roadblock_trigger"
      and current.player_id == player.id
      and current.tile_index == position then
    return current
  end
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" then
    return nil
  end
  for _, entry in ipairs(queue) do
    if entry.kind == "roadblock_trigger"
        and entry.player_id == player.id
        and entry.tile_index == position then
      return entry
    end
  end
  return nil
end

local function _build_chain_tip_text(game, player, position, had_vehicle)
  local tile = game and game.board and game.board.get_tile and game.board:get_tile(position) or nil
  local tile_name = tile and tile.name or tostring(position)
  if had_vehicle == true then
    return player.name .. " 在 " .. tile_name .. " 先触发路障，随后地雷炸毁座驾并送医"
  end
  return player.name .. " 在 " .. tile_name .. " 先触发路障，随后踩中地雷并送医"
end

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
  if mine.armed == false then
    return false
  end

  if player and mine.owner_id == player.id then
    local own_turn_started_count = player.status and player.status.own_turn_started_count or 0
    local placement_turn_count = mine.owner_turn_started_count_at_placement
    if placement_turn_count ~= nil then
      return own_turn_started_count > placement_turn_count + 1
    end
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
  local roadblock_trigger = _find_pending_roadblock_trigger(game, player, position)
  local chain_key = nil
  local focus_text = nil
  local tip_policy = nil
  local dedupe_key = nil
  local tip_source = nil
  if roadblock_trigger ~= nil then
    chain_key = _build_obstacle_chain_key(game, player, position)
    roadblock_trigger.chain_key = chain_key
    focus_text = _build_chain_tip_text(game, player, position, had_vehicle)
    tip_policy = "user"
    dedupe_key = "obstacle_chain:" .. chain_key
    tip_source = "obstacle_chain"
  end
  local hospital_index = game:player_relocate(player, {
    tile_type = "hospital",
    clear_seat = true,
    move_dir_mode = "clear",
  })
  game:set_player_status(player, "pending_location_effect", "hospital")
  local queued = action_anim_port.queue(game, {
    kind = "mine_trigger",
    player_id = player.id,
    tile_index = position,
    from_index = from_index,
    to_index = hospital_index,
    duration = action_anim_duration,
    cue_name = "mine_blast",
    chain_key = chain_key,
    focus_text = focus_text,
    tip_policy = tip_policy,
    dedupe_key = dedupe_key,
    tip_source = tip_source,
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
