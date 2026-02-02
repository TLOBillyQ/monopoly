local Logger = require("Components.Logger")
local Tile = require("Components.Tile")
local Roadblock = {}

local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }

local function _MakeCandidate(board, player, idx, dir, step, seen)
  assert(idx ~= nil, "missing idx")
  if seen[idx] or idx == player.position then
    return nil
  end
  seen[idx] = true
  local tile = board:GetTile(idx)
  assert(tile ~= nil, "missing tile: " .. tostring(idx))
  return {
    idx = idx,
    tile = tile,
    dir = dir,
    step = step,
  }
end

local function _ForwardIndices(board, player, distance)
  local list = {}
  local current = player.position
  local facing = player.status.move_dir
  for step = 1, distance do
    local next_idx, _, next_dir = board:StepForwardByFacing(current, facing, 1)
    current = next_idx
    facing = next_dir or facing
    table.insert(list, { idx = current, step = step, dir = "forward" })
  end
  return list
end

local function _BackwardIndices(board, player, distance)
  local list = {}
  local current = player.position
  local len = board:Length()
  local facing = assert(player.status.move_dir, "missing move_dir")
  for step = 1, distance do
    assert(board.map ~= nil, "missing board.map")
    assert(OPPOSITE[facing] ~= nil, "missing opposite dir: " .. tostring(facing))
    local prev = board:StepForwardByFacing(current, OPPOSITE[facing], 1)
    current = prev
    table.insert(list, { idx = current, step = step, dir = "backward" })
  end
  return list
end

local function _PriorityForCandidate(game, player, cand)
  local tile = cand.tile
  local board = game.board
  if board:HasRoadblock(cand.idx) or board:HasMine(cand.idx) then
    return nil
  end

  local st = nil
  if tile.type == "land" then
      st = Tile.GetState(game, tile)
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

local function _FormatLabel(cand)
  local dir_label = "后方"
  if cand.dir == "forward" then
    dir_label = "前方"
  end
  return dir_label .. cand.step .. "格：" .. cand.tile.name .. " (" .. cand.tile.type .. ")"
end

function Roadblock.Candidates(game, player, distance)
  local board = game.board
  local seen = {}
  local list = {}

  for _, entry in ipairs(_ForwardIndices(board, player, distance or 3)) do
    local cand = _MakeCandidate(board, player, entry.idx, entry.dir, entry.step, seen)
    if cand then
      cand.priority = _PriorityForCandidate(game, player, cand)
      if cand.priority then
        table.insert(list, cand)
      end
    end
  end

  for _, entry in ipairs(_BackwardIndices(board, player, distance or 3)) do
    local cand = _MakeCandidate(board, player, entry.idx, entry.dir, entry.step, seen)
    if cand then
      cand.priority = _PriorityForCandidate(game, player, cand)
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
    cand.label = _FormatLabel(cand)
  end

  return list
end

function Roadblock.PickBest(candidates)
  assert(candidates ~= nil and #candidates > 0, "missing roadblock candidates")
  return candidates[1]
end

function Roadblock.Apply(game, player, idx)
  assert(idx ~= nil, "missing idx")
  assert(game.board ~= nil, "missing board")
  game.board:PlaceRoadblock(idx)
  local tile = game.board:GetTile(idx)
  Logger.Event(player.name .. " 放置路障在 " .. tile.name)
  local queued = false
  assert(game.ui_port ~= nil, "missing ui_port")
  if game.ui_port.wait_action_anim then
    game:QueueActionAnim({
      kind = "roadblock",
      player_id = player.id,
      tile_index = idx,
    })
    queued = true
  end
  return { ok = true, action_anim = queued }
end

return Roadblock


