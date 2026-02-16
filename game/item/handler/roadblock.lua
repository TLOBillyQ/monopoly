local logger = require("core.logger")
local tile = require("game.tile")
local gameplay_rules = require("cfg.GameplayRules")
local roadblock = {}
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

local function _make_candidate(board, player, idx, dir, step, seen)
  assert(idx ~= nil, "missing idx")
  if seen[idx] or idx == player.position then
    return nil
  end
  seen[idx] = true
  local tile_obj = board:get_tile(idx)
  assert(tile_obj ~= nil, "missing tile: " .. tostring(idx))
  return {
    idx = idx,
    tile = tile_obj,
    dir = dir,
    step = step,
  }
end

local function _forward_indices(board, player, distance)
  local list = {}
  local current = player.position
  local facing = player.status.move_dir
  for step = 1, distance do
    local next_idx, _, next_dir = board:step_forward_by_facing(current, facing, 1)
    current = next_idx
    facing = next_dir or facing
    table.insert(list, { idx = current, step = step, dir = "forward" })
  end
  return list
end

local function _backward_indices(board, player, distance)
  local list = {}
  local current = player.position
  local facing = player.status.move_dir
  for step = 1, distance do
    local prev_idx, _, prev_dir = board:step_backward_by_facing(current, facing)
    current = prev_idx
    facing = prev_dir or facing
    table.insert(list, { idx = current, step = step, dir = "backward" })
  end
  return list
end

local function _priority_for_candidate(game, player, cand)
  local tile_obj = cand.tile
  local board = game.board
  if board:has_roadblock(cand.idx) or board:has_mine(cand.idx) then
    return nil
  end

  local st = nil
  if tile_obj.type == "land" then
      st = tile.get_state(game, tile_obj)
  end
  if cand.dir == "forward" then
    if tile_obj.type == "item" then
      return 1
    end
    if tile_obj.type == "land" and st and not st.owner_id then
      return 2
    end
    if tile_obj.type == "chance" then
      return 3
    end
  elseif cand.dir == "backward" then
    if tile_obj.type == "land" and st and st.owner_id == player.id then
      return 4
    end
    if tile_obj.type == "hospital" then
      return 5
    end
    if tile_obj.type == "tax" then
      return 6
    end
    if tile_obj.type == "mountain" then
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
  return dir_label .. cand.step .. "格：" .. cand.tile.name .. " (" .. cand.tile.type .. ")"
end

function roadblock.candidates(game, player, distance)
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

function roadblock.pick_best(candidates)
  assert(candidates ~= nil and #candidates > 0, "missing roadblock candidates")
  return candidates[1]
end

function roadblock.apply(game, player, idx)
  assert(idx ~= nil, "missing idx")
  assert(game.board ~= nil, "missing board")
  game.board:place_roadblock(idx)
  local tile_obj = game.board:get_tile(idx)
  logger.event(player.name .. " 放置路障在 " .. tile_obj.name)
  local queued = false
  assert(game.ui_port ~= nil, "missing ui_port")
  if game.ui_port.wait_action_anim then
    game:queue_action_anim({
      kind = "roadblock",
      player_id = player.id,
      tile_index = idx,
      duration = action_anim_duration,
    })
    queued = true
  end
  return { ok = true, action_anim = queued }
end

return roadblock
