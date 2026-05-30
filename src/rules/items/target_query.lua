local board_query = require("src.rules.board.query")

local target_query = {}

function target_query.find_best_tile(game, player, distance, opts)
  assert(game ~= nil, "missing game")
  assert(player ~= nil, "missing player")
  assert(opts ~= nil, "missing opts")
  local allow_self = opts.allow_self
  local score_fn = assert(opts.score_fn, "missing score_fn")
  local board = assert(game.board, "missing game.board")
  local best_idx = nil
  local best_value = nil
  local has_best = false

  local indices = board_query.indices_in_range(board, player.position, distance or 3)
  if allow_self then
    table.insert(indices, 1, player.position)
  end

  for _, idx in ipairs(indices) do
    if allow_self or idx ~= player.position then
      local tile = board:get_tile(idx)
      local value = assert(score_fn(tile, idx), "missing score for tile: " .. tostring(idx))
      if has_best then
        if value > best_value then
          best_idx = idx
          best_value = value
        end
      else
        has_best = true
        best_idx = idx
        best_value = value
      end
    end
  end

  return best_idx, best_value
end

return target_query

--[[ mutate4lua-manifest
version=2
projectHash=b20242011e435cd9
scope.0.id=chunk:src/rules/items/target_query.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=42
scope.0.semanticHash=d2b082f5008b371a
]]
