local board_query = require("src.game.systems.board.query")

local target_query = {}

function target_query.find_best_tile(game, player, distance, opts)
  local board = game.board
  assert(opts ~= nil, "missing opts")
  local allow_self = opts.allow_self
  local score_fn = assert(opts.score_fn, "missing score_fn")
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
          best_value = value
          best_idx = idx
        end
      else
        has_best = true
        best_value = value
        best_idx = idx
      end
    end
  end

  return best_idx, best_value
end

return target_query
