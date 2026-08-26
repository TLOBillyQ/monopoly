local event_kinds = require("src.config.gameplay.event_kinds")
local board_query = require("src.rules.board.query")
local timing = require("src.config.gameplay.timing")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local number_utils = require("src.foundation.number")
local facing_policy = require("src.rules.board.facing_policy")
local roadblock = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0
local ui_candidate_slots = 7

local function _make_candidate(board, player, idx, dir, step, seen)
  assert(idx ~= nil, "missing idx")
  if seen[idx] or idx == player.position then
    return nil
  end
  seen[idx] = true
  local tile = board:get_tile(idx)
  assert(tile ~= nil, "missing tile: " .. tostring(idx))
  return {
    idx = idx,
    tile = tile,
    dir = dir,
    step = step,
  }
end

local function _make_ui_candidate(board, idx, dir, step)
  local tile = board:get_tile(idx)
  assert(tile ~= nil, "missing tile: " .. tostring(idx))
  return {
    idx = idx,
    tile = tile,
    dir = dir,
    step = step,
    label = tile.name,
  }
end

local function _tile_distance(board, start_idx, idx)
  local start_tile = assert(board:get_tile(start_idx), "missing start tile: " .. tostring(start_idx))
  local tile = assert(board:get_tile(idx), "missing tile: " .. tostring(idx))
  return math.abs(start_tile.row - tile.row) + math.abs(start_tile.col - tile.col)
end

local function _build_manual_candidate(board, start_idx, idx)
  return _make_ui_candidate(board, idx, "nearby", _tile_distance(board, start_idx, idx))
end

local function _forward_indices(board, player, distance)
  local list = {}
  local current = player.position
  local facing = facing_policy.resolve_initial_facing("relative_forward", player)
  for step = 1, distance do
    local next_idx, _, next_facing = board:step_forward_by_facing(current, facing, 1)
    current = next_idx
    facing = next_facing
    table.insert(list, { idx = current, step = step, dir = "forward" })
  end
  return list
end

local function _backward_indices(board, player, distance)
  local list = {}
  local current = player.position
  local facing = facing_policy.resolve_initial_facing("relative_backward", player)
  for step = 1, distance do
    local prev_idx, _, next_facing = board:step_backward_by_facing(current, facing)
    current = prev_idx
    facing = next_facing
    table.insert(list, { idx = current, step = step, dir = "backward" })
  end
  return list
end

local function _append_unique_ui_candidate(list, seen, board, idx, dir, step)
  if seen[idx] then
    return false
  end
  seen[idx] = true
  list[#list + 1] = _make_ui_candidate(board, idx, dir, step)
  return true
end

local _FORWARD_PRIORITY_BY_TYPE = { item = 1, chance = 3 }

local function _forward_priority(tile, st)
  if tile.type == "land" then
    if st and not st.owner_id then
      return 2
    end
    return nil
  end
  return _FORWARD_PRIORITY_BY_TYPE[tile.type]
end

local function _own_land_backward(tile, st, player)
  return tile.type == "land" and st ~= nil and st.owner_id == player.id
end

local function _backward_priority(tile, st, player)
  if _own_land_backward(tile, st, player) then
    return 4
  end
  if tile.type == "hospital" then
    return 5
  end
  if tile.type == "tax" then
    return 6
  end
  if tile.type == "mountain" then
    return 7
  end
  return nil
end

local function _blocked_by_obstacle(board, cand)
  return board:has_roadblock(cand.idx) or board:has_mine(cand.idx)
end

local function _tile_state_for(tile, game)
  if tile.type == "land" then
    return tile.get_state(game, tile)
  end
  return nil
end

local function _priority_for_candidate(game, player, cand)
  local tile = cand.tile
  local board = game.board
  if _blocked_by_obstacle(board, cand) then
    return nil
  end

  local st = _tile_state_for(tile, game)
  if cand.dir == "forward" then
    return _forward_priority(tile, st)
  elseif cand.dir == "backward" then
    return _backward_priority(tile, st, player)
  end
  return nil
end

local function _format_label(cand)
  local dir_label = "后方"
  if cand.dir == "forward" then
    dir_label = "前方"
  end
  return dir_label .. number_utils.format_integer_part(cand.step) .. "格：" .. cand.tile.name .. " (" .. cand.tile.type .. ")"
end

local function _append_auto_candidate(list, game, player, board, seen, entry)
  local cand = _make_candidate(board, player, entry.idx, entry.dir, entry.step, seen)
  if not cand then
    return
  end
  cand.priority = _priority_for_candidate(game, player, cand)
  if cand.priority then
    table.insert(list, cand)
  end
end

function roadblock.auto_candidates(game, player, distance)
  local board = game.board
  local seen = {}
  local list = {}
  distance = distance or 3

  for _, entry in ipairs(_forward_indices(board, player, distance)) do
    _append_auto_candidate(list, game, player, board, seen, entry)
  end

  for _, entry in ipairs(_backward_indices(board, player, distance)) do
    _append_auto_candidate(list, game, player, board, seen, entry)
  end

  table.sort(list, function(a, b)
    if a.priority == b.priority then
      return a.step < b.step
    end
    return a.priority < b.priority
  end)

  for _, cand in ipairs(list) do
    cand.label = _format_label(cand)
  end

  return list
end

function roadblock.manual_candidates(game, player, distance)
  local board = game.board
  local list = {}
  local seen = {}
  _append_unique_ui_candidate(list, seen, board, player.position, "current", 0)
  for _, idx in ipairs(board_query.indices_in_range(board, player.position, distance or 3)) do
    if not seen[idx] then
      seen[idx] = true
      list[#list + 1] = _build_manual_candidate(board, player.position, idx)
    end
    if #list >= ui_candidate_slots then
      break
    end
  end

  return list
end

function roadblock.is_ui_candidate(game, player, idx, distance)
  local target_idx = number_utils.to_integer(idx)
  if target_idx == nil then
    return false
  end
  for _, cand in ipairs(roadblock.manual_candidates(game, player, distance)) do
    if cand.idx == target_idx then
      return true
    end
  end
  return false
end

function roadblock.pick_best(candidates)
  assert(candidates ~= nil and #candidates > 0, "missing roadblock candidates")
  return candidates[1]
end

function roadblock.apply(game, player, idx)
  assert(idx ~= nil, "missing idx")
  assert(game.board ~= nil, "missing board")
  game:place_roadblock(idx)
  local tile = game.board:get_tile(idx)
  event_feed.publish(game, {
    kind = event_kinds.roadblock_placed,
    text = player.name .. " 放置路障在 " .. tile.name,
  })
  local queued = action_anim_port.queue(game, {
    kind = "roadblock",
    player_id = player.id,
    tile_index = idx,
    duration = action_anim_duration,
  })
  return { ok = true, action_anim = queued }
end

return roadblock

--[[ mutate4lua-manifest
version=4
projectHash=f7016c69cf583ab3
scope.0.id=chunk:src/rules/items/roadblock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=234
scope.0.semanticHash=f312214023630f70
scope.1.id=function:_make_candidate
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=26
scope.1.semanticHash=c4b84867b20d3556
scope.2.id=function:_make_ui_candidate
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=38
scope.2.semanticHash=1291e19e09b5eef4
scope.3.id=function:_tile_distance
scope.3.kind=function
scope.3.startLine=40
scope.3.endLine=44
scope.3.semanticHash=4aa6d7c6b28c6ea2
scope.4.id=function:_build_manual_candidate
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=48
scope.4.semanticHash=29ac3c6c9bd18993
scope.5.id=function:_forward_indices
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=61
scope.5.semanticHash=d0752ff0a198e835
scope.6.id=function:_backward_indices
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=74
scope.6.semanticHash=0c05ce05c907bb3b
scope.7.id=function:_append_unique_ui_candidate
scope.7.kind=function
scope.7.startLine=76
scope.7.endLine=83
scope.7.semanticHash=e65dfe1ba13c69af
scope.8.id=function:_forward_priority
scope.8.kind=function
scope.8.startLine=87
scope.8.endLine=95
scope.8.semanticHash=ca7b5e1bfc563b71
scope.9.id=function:_backward_priority
scope.9.kind=function
scope.9.startLine=97
scope.9.endLine=111
scope.9.semanticHash=6c2095d1e46b022e
scope.10.id=function:_priority_for_candidate
scope.10.kind=function
scope.10.startLine=113
scope.10.endLine=130
scope.10.semanticHash=c25d5acc187bed26
scope.11.id=function:_format_label
scope.11.kind=function
scope.11.startLine=132
scope.11.endLine=138
scope.11.semanticHash=31b9579720fdfe7c
scope.12.id=function:_append_auto_candidate
scope.12.kind=function
scope.12.startLine=140
scope.12.endLine=149
scope.12.semanticHash=d4cb0ce0dd0a872a
scope.13.id=function:roadblock.auto_candidates
scope.13.kind=function
scope.13.startLine=151
scope.13.endLine=177
scope.13.semanticHash=f04f80052bceb15e
scope.14.id=function:<anonymous>
scope.14.kind=function
scope.14.startLine=165
scope.14.endLine=170
scope.14.semanticHash=79dbe675000f8eca
scope.15.id=function:roadblock.manual_candidates
scope.15.kind=function
scope.15.startLine=179
scope.15.endLine=195
scope.15.semanticHash=27dbf6ddb9854aae
scope.16.id=function:roadblock.is_ui_candidate
scope.16.kind=function
scope.16.startLine=197
scope.16.endLine=208
scope.16.semanticHash=eb18ee1e1de8d25d
scope.17.id=function:roadblock.pick_best
scope.17.kind=function
scope.17.startLine=210
scope.17.endLine=213
scope.17.semanticHash=393bcea739d982b6
scope.18.id=function:roadblock.apply
scope.18.kind=function
scope.18.startLine=215
scope.18.endLine=231
scope.18.semanticHash=1d13f79dadfcb699
]]
