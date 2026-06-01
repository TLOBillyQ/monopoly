local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local action_anim_port = require("src.foundation.ports.action_anim")
local angel_feedback = require("src.rules.items.angel_feedback")

local mine_effect = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local function _build_obstacle_chain_key(game, player, position)
  local turn = game and game.turn or nil
  local turn_count = turn and turn.turn_count or 0
  return tostring(turn_count) .. ":" .. tostring(player.id) .. ":" .. tostring(position)
end

local function _is_matching_roadblock_trigger(entry, player, position)
  return entry
    and entry.kind == "roadblock_trigger"
    and entry.player_id == player.id
    and entry.tile_index == position
end

local function _find_pending_roadblock_trigger(game, player, position)
  if not (game and game.turn) then
    return nil
  end
  local current = game.turn.action_anim
  if _is_matching_roadblock_trigger(current, player, position) then
    return current
  end
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" then
    return nil
  end
  for _, entry in ipairs(queue) do
    if _is_matching_roadblock_trigger(entry, player, position) then
      return entry
    end
  end
  return nil
end

local function _build_chain_tip_text(game, player, position)
  local tile = game and game.board and game.board.get_tile and game.board:get_tile(position) or nil
  local tile_name = tile and tile.name or tostring(position)
  return player.name .. " 在 " .. tile_name .. "踩中地雷"
end

local function _is_mine_grace_expired(player, mine)
  if not (player and mine.owner_id == player.id) then return true end
  local placement_turn_count = mine.owner_turn_started_count_at_placement
  if placement_turn_count == nil then return true end
  local own_count = player.status and player.status.own_turn_started_count or 0
  return own_count > placement_turn_count + 1
end

function mine_effect.can_trigger(game, player, position)
  local board = game and game.board or nil
  if not (board and position and board:has_mine(position)) then
    return false
  end
  local mine = board:get_mine(position)
  if type(mine) ~= "table" then return true end
  if mine.armed == false then return false end
  return _is_mine_grace_expired(player, mine)
end

function mine_effect.apply(game, player, position)
  assert(game ~= nil, "missing game")
  assert(game.board, "missing board")
  assert(player ~= nil, "missing player")
  assert(position ~= nil, "missing position")

  if game:angel_immune_to_item(player, item_ids.mine) then
    angel_feedback.publish(game, player, "地雷", { tile_index = position })
    game:clear_mine(position)
    return { detonated = true, protected = true }
  end

  game:clear_mine(position)
  local from_index = position
  local roadblock_trigger = _find_pending_roadblock_trigger(game, player, position)
  local chain_key = nil
  local focus_text = nil
  local tip_policy = nil
  local dedupe_key = nil
  local tip_source = nil
  if roadblock_trigger ~= nil then
    chain_key = _build_obstacle_chain_key(game, player, position)
    focus_text = _build_chain_tip_text(game, player, position)
    tip_policy = "user"
    dedupe_key = "obstacle_chain:" .. chain_key
    tip_source = "obstacle_chain"
  end
  local hospital_index = game:player_relocate(player, {
    tile_type = "hospital",
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
        player.name .. "触发地雷",
      },
      effects = {
        { player_id = player.id, effect = "hospital" },
      },
      next_state = "end_turn",
      next_args = { player = player },
    },
  }
end

mine_effect._M_test = {
  _find_pending_roadblock_trigger = _find_pending_roadblock_trigger,
}

return mine_effect

--[[ mutate4lua-manifest
version=2
projectHash=455533d324ee9169
scope.0.id=chunk:src/rules/effects/mine.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=138
scope.0.semanticHash=02ac3b4b99599853
scope.0.lastMutatedAt=2026-06-01T04:28:24Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=13
scope.0.lastMutationKilled=12
scope.1.id=function:_build_obstacle_chain_key:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=13
scope.1.semanticHash=06884cbc4c4c8d4c
scope.1.lastMutatedAt=2026-06-01T04:28:24Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=10
scope.1.lastMutationKilled=10
scope.2.id=function:_is_matching_roadblock_trigger:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=20
scope.2.semanticHash=3d3f4ee742b14b13
scope.2.lastMutatedAt=2026-06-01T04:28:24Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:_build_chain_tip_text:42
scope.3.kind=function
scope.3.startLine=42
scope.3.endLine=46
scope.3.semanticHash=017444b38b9141f9
scope.3.lastMutatedAt=2026-06-01T04:28:24Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=survived
scope.3.lastMutationSites=10
scope.3.lastMutationKilled=9
scope.4.id=function:_is_mine_grace_expired:48
scope.4.kind=function
scope.4.startLine=48
scope.4.endLine=54
scope.4.semanticHash=525f532b77860fed
scope.4.lastMutatedAt=2026-06-01T04:28:24Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=survived
scope.4.lastMutationSites=12
scope.4.lastMutationKilled=11
scope.5.id=function:mine_effect.can_trigger:56
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=65
scope.5.semanticHash=c2f79b18459b72a4
scope.5.lastMutatedAt=2026-06-01T04:28:24Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=16
scope.5.lastMutationKilled=16
scope.6.id=function:mine_effect.apply:67
scope.6.kind=function
scope.6.startLine=67
scope.6.endLine=131
scope.6.semanticHash=88a44173fa89398b
scope.6.lastMutatedAt=2026-06-01T04:28:24Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=28
scope.6.lastMutationKilled=28
]]
