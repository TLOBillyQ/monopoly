local Pricing = require("src.gameplay.domain.land_pricing")

local BoardUtils = {}

function BoardUtils.indices_in_range(board, start, distance)
  local len = board:length()
  local seen = {}
  local list = {}
  for step = 1, distance do
    local forward = start + step
    if forward > len then
      forward = forward - len
    end
    if not seen[forward] then
      table.insert(list, forward)
      seen[forward] = true
    end

    local back = start - step
    if back < 1 then
      back = len + back
    end
    if not seen[back] then
      table.insert(list, back)
      seen[back] = true
    end
  end
  return list
end

function BoardUtils.total_invested(tile, level)
  if not tile then
    return 0
  end
  return Pricing.total_invested(tile, level or 0)
end

function BoardUtils.find_best_tile(game, player, distance, opts)
  local board = game.board
  local allow_self = opts and opts.allow_self
  local score_fn = opts and opts.score_fn
  local best_idx = nil
  local best_value = nil
  
  local indices = BoardUtils.indices_in_range(board, player.position, distance or 3)
  if allow_self then
    table.insert(indices, 1, player.position)
  end
  
  for _, idx in ipairs(indices) do
    if allow_self or idx ~= player.position then
      local tile = board:get_tile(idx)
      local value = score_fn and score_fn(tile, idx)
      if value ~= nil and (best_value == nil or value > best_value) then
        best_value = value
        best_idx = idx
      end
    end
  end
  return best_idx, best_value
end

return BoardUtils
