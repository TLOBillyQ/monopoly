local logger = require("src.core.utils.logger")
local tile = require("src.rules.board.tile")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local action_anim_port = require("src.core.ports.action_anim_port")
local number_utils = require("src.core.utils.number_utils")
local facing_policy = require("src.rules.board.facing_policy")
local roadblock = {}
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0
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

local function _forward_indices(board, player, distance)
  local list = {}
  local current = player.position
  local facing = facing_policy.resolve_initial_facing("relative_forward", player)
  for step = 1, distance do
    local next_idx, _, next_dir = board:step_forward_by_facing(current, facing, 1)
    current = next_idx
    facing = next_dir
    table.insert(list, { idx = current, step = step, dir = "forward" })
  end
  return list
end

local function _backward_indices(board, player, distance)
  local list = {}
  local current = player.position
  local facing = facing_policy.resolve_initial_facing("relative_backward", player)
  for step = 1, distance do
    local prev_idx, _, prev_dir = board:step_backward_by_facing(current, facing)
    current = prev_idx
    facing = prev_dir
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

local function _priority_for_candidate(game, player, cand)
  local tile = cand.tile
  local board = game.board
  if board:has_roadblock(cand.idx) or board:has_mine(cand.idx) then
    return nil
  end

  local st = nil
  if tile.type == "land" then
      st = tile.get_state(game, tile)
  end
  if cand.dir == "forward" then
    if tile.type == "item" then
      return 1
    end
    if tile.type == "land" and st and not st.owner_id then
      return 2
    end
    if tile.type == "chance" then
      return 3
    end
  elseif cand.dir == "backward" then
    if tile.type == "land" and st and st.owner_id == player.id then
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

function roadblock.auto_candidates(game, player, distance)
  local board = game.board
  local seen = {}
  local list = {}

  for _, entry in ipairs(_forward_indices(board, player, distance or 3)) do
    local cand = _make_candidate(board, player, entry.idx, entry.dir, entry.step, seen)
    if cand then
      cand.priority = _priority_for_candidate(game, player, cand)
      if cand.priority then
        table.insert(list, cand)
      end
    end
  end

  for _, entry in ipairs(_backward_indices(board, player, distance or 3)) do
    local cand = _make_candidate(board, player, entry.idx, entry.dir, entry.step, seen)
    if cand then
      cand.priority = _priority_for_candidate(game, player, cand)
      if cand.priority then
        table.insert(list, cand)
      end
    end
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

function roadblock.candidates(game, player, distance)
  return roadblock.auto_candidates(game, player, distance)
end

function roadblock.ui_candidates(game, player, distance)
  local board = game.board
  local list = {}
  local seen = {}
  _append_unique_ui_candidate(list, seen, board, player.position, "current", 0)
  local max_steps = board:length() - 1
  local forward = _forward_indices(board, player, max_steps)
  local backward = _backward_indices(board, player, max_steps)

  for step = 1, max_steps do
    local forward_entry = forward[step]
    if forward_entry then
      _append_unique_ui_candidate(list, seen, board, forward_entry.idx, forward_entry.dir, forward_entry.step)
      if #list >= ui_candidate_slots then
        break
      end
    end
    local backward_entry = backward[step]
    if backward_entry then
      _append_unique_ui_candidate(list, seen, board, backward_entry.idx, backward_entry.dir, backward_entry.step)
      if #list >= ui_candidate_slots then
        break
      end
    end
  end

  return list
end

function roadblock.is_ui_candidate(game, player, idx, distance)
  local target_idx = number_utils.to_integer(idx)
  if target_idx == nil then
    return false
  end
  for _, cand in ipairs(roadblock.ui_candidates(game, player, distance)) do
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
  logger.event(player.name .. " 放置路障在 " .. tile.name)
  local queued = action_anim_port.queue(game, {
    kind = "roadblock",
    player_id = player.id,
    tile_index = idx,
    duration = action_anim_duration,
  })
  return { ok = true, action_anim = queued }
end

return roadblock
