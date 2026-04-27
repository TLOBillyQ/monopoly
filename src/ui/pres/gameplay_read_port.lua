local number_utils = require("src.core.utils.number")
local vehicle_catalog = require("src.config.gameplay.vehicle_catalog")

local gameplay_read_port = {}

local function _normalize_level(level)
  local as_int = number_utils.to_integer(level)
  if as_int == nil or as_int < 0 then
    return 0
  end
  return as_int
end

local function _purchase_price(tile)
  if type(tile) ~= "table" then
    return 0
  end
  local price = tile.price
  if not number_utils.is_numeric(price) then
    return 0
  end
  return price
end

function gameplay_read_port.resolve_vehicle_seat_id(seat_id)
  if seat_id == nil then
    return nil
  end
  if not vehicle_catalog.has(seat_id) then
    return nil
  end
  return seat_id
end

function gameplay_read_port.total_land_invested(tile, level)
  local total = _purchase_price(tile)
  local costs = tile and tile.upgrade_costs or nil
  if type(costs) ~= "table" then
    return total
  end
  local max_level = _normalize_level(level)
  local max_cost_index = #costs
  if max_level > max_cost_index then
    max_level = max_cost_index
  end
  for i = 1, max_level do
    total = total + (costs[i] or 0)
  end
  return total
end

return gameplay_read_port
