local common = require("arch_view.common")

local route_engine = {}

local SAME_LAYER_LANE_STEP = 24.0
local CROSS_LAYER_LANE_STEP = 14.0
local NODE_PORT_STEP = 14.0

local function _copy_point(point)
  return { point[1], point[2] }
end

local function _build_index_map(edge_groups)
  local result = {}
  for group_key, edges in pairs(edge_groups or {}) do
    table.sort(edges, function(left, right)
      if left.sort_key == right.sort_key then
        return left.id < right.id
      end
      return left.sort_key < right.sort_key
    end)
    local count = #edges
    for index, entry in ipairs(edges) do
      result[entry.id] = {
        index = index,
        count = count,
        group_key = group_key,
      }
    end
  end
  return result
end

local function _bucketize(edges)
  local outgoing = {}
  local incoming = {}
  local lane_groups = {}

  for _, edge in ipairs(edges or {}) do
    outgoing[edge.from] = outgoing[edge.from] or {}
    outgoing[edge.from][#outgoing[edge.from] + 1] = {
      id = edge.id,
      sort_key = tostring(edge.to),
    }

    incoming[edge.to] = incoming[edge.to] or {}
    incoming[edge.to][#incoming[edge.to] + 1] = {
      id = edge.id,
      sort_key = tostring(edge.from),
    }

    local lane_key = tostring(edge.from_layer) .. "->" .. tostring(edge.to_layer)
    lane_groups[lane_key] = lane_groups[lane_key] or {}
    lane_groups[lane_key][#lane_groups[lane_key] + 1] = {
      id = edge.id,
      sort_key = tostring(edge.from) .. "->" .. tostring(edge.to),
    }
  end

  return {
    outgoing = _build_index_map(outgoing),
    incoming = _build_index_map(incoming),
    lanes = _build_index_map(lane_groups),
  }
end

local function _port_offset(index_info)
  if index_info == nil then
    return 0.0
  end
  return ((index_info.index or 1) - ((index_info.count or 1) + 1) / 2.0) * NODE_PORT_STEP
end

local function _lane_offset(index_info, same_layer)
  if index_info == nil then
    return 0.0
  end
  local step = same_layer and SAME_LAYER_LANE_STEP or CROSS_LAYER_LANE_STEP
  return ((index_info.index or 1) - 1) * step
end

local function _route_same_layer(edge, bucket_info)
  local from_rect = edge.from_rect
  local to_rect = edge.to_rect
  local from_offset = _port_offset(bucket_info.outgoing[edge.id])
  local to_offset = _port_offset(bucket_info.incoming[edge.id])
  local lane_offset = _lane_offset(bucket_info.lanes[edge.id], true)
  local lane_y = math.min(from_rect.y, to_rect.y) - 34.0 - lane_offset
  local from_x = from_rect.x + from_rect.width / 2.0 + from_offset
  local to_x = to_rect.x + to_rect.width / 2.0 + to_offset

  return {
    { from_x, from_rect.y },
    { from_x, lane_y },
    { to_x, lane_y },
    { to_x, to_rect.y },
  }
end

local function _route_cross_layer(edge, bucket_info)
  local from_rect = edge.from_rect
  local to_rect = edge.to_rect
  local from_offset = _port_offset(bucket_info.outgoing[edge.id])
  local to_offset = _port_offset(bucket_info.incoming[edge.id])
  local lane_offset = _lane_offset(bucket_info.lanes[edge.id], false)

  local start_x = from_rect.x + from_rect.width / 2.0 + from_offset
  local start_y = from_rect.y + from_rect.height
  local end_x = to_rect.x + to_rect.width / 2.0 + to_offset
  local end_y = to_rect.y
  local lane_y = ((start_y + end_y) / 2.0) + lane_offset

  return {
    { start_x, start_y },
    { start_x, lane_y },
    { end_x, lane_y },
    { end_x, end_y },
  }
end

function route_engine.route_edges(edges)
  local bucket_info = _bucketize(edges or {})
  local routed = {}

  for _, edge in ipairs(edges or {}) do
    local same_layer = edge.from_layer == edge.to_layer
    local route_points
    if same_layer then
      route_points = _route_same_layer(edge, bucket_info)
    else
      route_points = _route_cross_layer(edge, bucket_info)
    end

    local copied = {}
    for index, point in ipairs(route_points or {}) do
      copied[index] = _copy_point(point)
    end

    local next_edge = {}
    for key, value in pairs(edge) do
      next_edge[key] = value
    end
    next_edge.route_points = copied
    routed[#routed + 1] = next_edge
  end

  return routed
end

return route_engine
