local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local action_anim_port = require("src.foundation.ports.action_anim")
local angel_feedback = require("src.rules.items.angel_feedback")

local mine_effect = {}
local action_anim_duration = timing.action_anim_default_seconds -- config 恒为 1.0,无需 or 1.0 兜底

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

local function _find_queued_roadblock_trigger(queue, player, position)
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

-- 正在播的 action_anim 优先,其次才翻队列。
local function _find_pending_roadblock_trigger(game, player, position)
  if not (game and game.turn) then
    return nil
  end
  local current = game.turn.action_anim
  if _is_matching_roadblock_trigger(current, player, position) then
    return current
  end
  return _find_queued_roadblock_trigger(game.turn.action_anim_queue, player, position)
end

local function _tile_at(game, position)
  return game and game.board and game.board.get_tile and game.board:get_tile(position) or nil
end

local function _tile_name_or_position(tile, position)
  return tile and tile.name or tostring(position)
end

local function _build_chain_tip_text(game, player, position)
  local tile = _tile_at(game, position)
  local tile_name = _tile_name_or_position(tile, position)
  return player.name .. " 在 " .. tile_name .. "踩中地雷"
end

local function _is_mine_grace_expired(game, player, mine)
  if not (player and mine.owner_id == player.id) then return true end
  local placement_turn_count = mine.owner_turn_started_count_at_placement
  if placement_turn_count == nil then return true end
  return game:player_own_turn_started_count(player) > placement_turn_count + 1
end

local function _game_board(game)
  return game and game.board or nil
end

local function _mine_at_position(game, position)
  local board = _game_board(game)
  if board and position and board:has_mine(position) then
    return board:get_mine(position)
  end
  return nil
end

-- 非表地雷视为「可直接触发」;表地雷需已武装且宽限期已过。
local function _mine_can_trigger(game, player, mine)
  if type(mine) ~= "table" then
    return true
  end
  if mine.armed == false then
    return false
  end
  return _is_mine_grace_expired(game, player, mine)
end

function mine_effect.can_trigger(game, player, position)
  local mine = _mine_at_position(game, position)
  if mine == nil then
    return false
  end
  return _mine_can_trigger(game, player, mine)
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
  _build_chain_tip_text = _build_chain_tip_text,
}

return mine_effect

--[[ mutate4lua-manifest
version=4
projectHash=eeac616e4322874d
scope.0.id=chunk:src/rules/effects/mine.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=170
scope.0.semanticHash=e41f9cde239082c4
scope.1.id=function:_build_obstacle_chain_key
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=13
scope.1.semanticHash=9a5b6e25c52cb4dc
scope.2.id=function:_is_matching_roadblock_trigger
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=20
scope.2.semanticHash=dd8381a0365259ab
scope.3.id=function:_find_queued_roadblock_trigger
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=32
scope.3.semanticHash=7050e818d733c4fc
scope.4.id=function:_find_pending_roadblock_trigger
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=44
scope.4.semanticHash=5382cb7157440f45
scope.5.id=function:_tile_at
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=48
scope.5.semanticHash=3043e87320c3a305
scope.6.id=function:_tile_name_or_position
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=52
scope.6.semanticHash=57ed54f641b77289
scope.7.id=function:_build_chain_tip_text
scope.7.kind=function
scope.7.startLine=54
scope.7.endLine=58
scope.7.semanticHash=269329fd5d49de7c
scope.8.id=function:_is_mine_grace_expired
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=65
scope.8.semanticHash=6fda15f89c18da14
scope.9.id=function:_game_board
scope.9.kind=function
scope.9.startLine=67
scope.9.endLine=69
scope.9.semanticHash=616a2ca60599c94f
scope.10.id=function:_mine_at_position
scope.10.kind=function
scope.10.startLine=71
scope.10.endLine=77
scope.10.semanticHash=b4e535bdcdce0b73
scope.11.id=function:_mine_can_trigger
scope.11.kind=function
scope.11.startLine=80
scope.11.endLine=88
scope.11.semanticHash=986830708b3f3358
scope.12.id=function:mine_effect.can_trigger
scope.12.kind=function
scope.12.startLine=90
scope.12.endLine=96
scope.12.semanticHash=a9d3447750ab3c4b
scope.13.id=function:mine_effect.apply
scope.13.kind=function
scope.13.startLine=98
scope.13.endLine=162
scope.13.semanticHash=120cb220bcca4f28
]]
