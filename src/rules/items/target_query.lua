local board_query = require("src.rules.board.query")

local target_query = {}

local function _validate_find_best_tile_args(game, player, opts)
  assert(game ~= nil, "missing game")
  assert(player ~= nil, "missing player")
  assert(opts ~= nil, "missing opts")
  local score_fn = assert(opts.score_fn, "missing score_fn")
  local board = assert(game.board, "missing game.board")
  return score_fn, board
end

local function _filter_self_indices(indices, position, allow_self)
  if allow_self then
    table.insert(indices, 1, position)
    return
  end
  for i, idx in ipairs(indices) do
    if idx == position then
      table.remove(indices, i)
      break
    end
  end
end

local function _find_highest_score(board, indices, score_fn)
  local best_idx = nil
  local best_value = nil
  for _, idx in ipairs(indices) do
    local tile = board:get_tile(idx)
    local value = assert(score_fn(tile, idx), "missing score for tile: " .. tostring(idx))
    if not best_idx or value > best_value then
      best_idx = idx
      best_value = value
    end
  end
  return best_idx, best_value
end

function target_query.find_best_tile(game, player, distance, opts)
  local score_fn, board = _validate_find_best_tile_args(game, player, opts)
  local indices = board_query.indices_in_range(board, player.position, distance or 3)
  _filter_self_indices(indices, player.position, opts.allow_self)
  return _find_highest_score(board, indices, score_fn)
end

return target_query

--[[ mutate4lua-manifest
version=2
projectHash=76ef407bbc72335b
scope.0.id=chunk:src/rules/items/target_query.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=49
scope.0.semanticHash=d144494b4addcaac
scope.0.lastMutatedAt=2026-06-01T12:35:09Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=11
scope.0.lastMutationKilled=9
scope.1.id=function:_validate_find_best_tile_args:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=12
scope.1.semanticHash=50a1cda986ed2204
scope.1.lastMutatedAt=2026-06-01T12:35:09Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:target_query.find_best_tile:41
scope.2.kind=function
scope.2.startLine=41
scope.2.endLine=46
scope.2.semanticHash=796a8e59196c7a48
scope.2.lastMutatedAt=2026-06-01T12:35:09Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
]]
