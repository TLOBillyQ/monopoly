local builder = {}

local turn_left = {
  up = "left",
  left = "down",
  down = "right",
  right = "up",
}

local turn_right = {
  up = "right",
  right = "down",
  down = "left",
  left = "up",
}

local function _assert_unique_ids(tile_ids)
  local seen = {}
  for i, tile_id in ipairs(tile_ids) do
    assert(tile_id ~= nil, "missing tile id at index: " .. tostring(i))
    assert(seen[tile_id] == nil, "duplicate tile id in ring map: " .. tostring(tile_id))
    seen[tile_id] = true
  end
end

local function _build_index_by_id(tile_ids)
  local out = {}
  for index, tile_id in ipairs(tile_ids) do
    out[tile_id] = index
  end
  return out
end

local function _next_index(index, total)
  if index >= total then
    return 1
  end
  return index + 1
end

local function _prev_index(index, total)
  if index <= 1 then
    return total
  end
  return index - 1
end

local function _direction(index_by_id, from_id, to_id, total)
  local from_index = assert(index_by_id[from_id], "missing from_id: " .. tostring(from_id))
  local to_index = assert(index_by_id[to_id], "missing to_id: " .. tostring(to_id))
  if to_index == _next_index(from_index, total) then
    return "right"
  end
  if to_index == _prev_index(from_index, total) then
    return "left"
  end
  assert(false, "invalid direction in ring map: " .. tostring(from_id) .. " -> " .. tostring(to_id))
end

function builder.build(opts)
  assert(type(opts) == "table", "missing ring map opts")
  local tile_ids = assert(opts.tile_ids, "missing opts.tile_ids")
  assert(type(tile_ids) == "table" and #tile_ids >= 3, "ring map requires at least 3 tiles")

  _assert_unique_ids(tile_ids)

  local start_id = assert(opts.start_id, "missing opts.start_id")
  local market_id = assert(opts.market_id, "missing opts.market_id")

  local index_by_id = _build_index_by_id(tile_ids)
  assert(index_by_id[start_id] ~= nil, "start_id not found in tile_ids")
  assert(index_by_id[market_id] ~= nil, "market_id not found in tile_ids")

  local total = #tile_ids
  local neighbors = {}
  local outer_next = {}
  local outer_prev = {}

  for index, tile_id in ipairs(tile_ids) do
    local next_id = tile_ids[_next_index(index, total)]
    local prev_id = tile_ids[_prev_index(index, total)]

    outer_next[tile_id] = next_id
    outer_prev[tile_id] = prev_id

    neighbors[tile_id] = {
      right = next_id,
      left = prev_id,
    }
  end

  local map = {
    path = tile_ids,
    neighbors = neighbors,
    outer_next = outer_next,
    outer_prev = outer_prev,
    entry_points = {},
    branches = {},
    start_id = start_id,
    market_id = market_id,
    direction = function(from_id, to_id)
      return _direction(index_by_id, from_id, to_id, total)
    end,
    turn_left = turn_left,
    turn_right = turn_right,
  }

  return map
end

return builder
