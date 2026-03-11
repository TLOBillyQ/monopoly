local board_query = require("src.game.systems.board.query")
local property_value = require("src.game.systems.commerce.property_value")
local target_query = require("src.game.systems.items.target_query")

local board_utils = {}

function board_utils.queue_walk(queue, visit)
  return board_query.queue_walk(queue, visit)
end

function board_utils.indices_in_range(board, start, distance)
  return board_query.indices_in_range(board, start, distance)
end

function board_utils.total_invested(tile, level)
  return property_value.total_invested(tile, level)
end

function board_utils.find_best_tile(game, player, distance, opts)
  return target_query.find_best_tile(game, player, distance, opts)
end

return board_utils
