local logger = require("src.util.logger")
local Tile = require("src.core.tile")
local Roadblock = {}

local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }

local function make_candidate(board, player, idx, dir, step, seen)
  if not idx or seen[idx] or idx == player.position then
    return nil
  end
  seen[idx] = true
  local tile = board:get_tile(idx)
  if not tile then
    return nil
  end
  return {
    idx = idx,
    tile = tile,
    dir = dir,
    step = step,
  }
end

local function forward_indices(board, player, distance)
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

local function backward_indices(board, player, distance)
  local list = {}
  local current = player.position
  local len = board:length()
  local facing = player.status.move_dir
  for step = 1, distance do
    local prev = nil
    if board.map and facing and OPPOSITE[facing] then
      prev = board:step_forward_by_facing(current, OPPOSITE[facing], 1)
    end
    if not prev then
      prev = current - 1
      if prev < 1 then
        prev = len + prev
      end
    end
    current = prev
    table.insert(list, { idx = current, step = step, dir = "backward" })
  end
  return list
end

local function priority_for_candidate(game, player, cand)
  local tile = cand.tile
  local board = game.board
  if board:has_roadblock(cand.idx) or board:has_mine(cand.idx) then
    return nil
  end

  local st = nil
  if tile.type == "land" then
    st = Tile.get_state(game, tile)
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

local function format_label(cand)
  local dir_label = "后方"
  if cand.dir == "forward" then
    dir_label = "前方"
  end
  return dir_label .. cand.step .. "格：" .. cand.tile.name .. " (" .. cand.tile.type .. ")"
end

function Roadblock.candidates(game, player, distance)
  local board = game.board
  local seen = {}
  local list = {}

  for _, entry in ipairs(forward_indices(board, player, distance or 3)) do
    local cand = make_candidate(board, player, entry.idx, entry.dir, entry.step, seen)
    if cand then
      cand.priority = priority_for_candidate(game, player, cand)
      if cand.priority then
        table.insert(list, cand)
      end
    end
  end

  for _, entry in ipairs(backward_indices(board, player, distance or 3)) do
    local cand = make_candidate(board, player, entry.idx, entry.dir, entry.step, seen)
    if cand then
      cand.priority = priority_for_candidate(game, player, cand)
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
    cand.label = format_label(cand)
  end

  return list
end

function Roadblock.pick_best(candidates)
  if not candidates or #candidates == 0 then
    return nil
  end
  return candidates[1]
end

function Roadblock.apply(game, player, idx)
  if not idx then
    return false
  end
  if not game.board then
    logger.warn("缺少 Board，无法放置路障")
    return false
  end
  game.board:place_roadblock(idx)
  local tile = game.board:get_tile(idx)
  logger.event(player.name .. " 放置路障在 " .. tile.name)
  local queued = false
  if game.ui_port and game.ui_port.wait_action_anim then
    game:queue_action_anim({
      kind = "roadblock",
      player_id = player.id,
      tile_index = idx,
    })
    queued = true
  end
  return { ok = true, action_anim = queued }
end

return Roadblock
