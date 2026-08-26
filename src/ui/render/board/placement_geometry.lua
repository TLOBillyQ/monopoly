-- 落位几何计算:地面位置解析、占用槽位与网格偏移。纯计算,不触碰宿主单元与动画状态。
local board_geometry = require("src.config.gameplay.camera_follow")

local geometry = {}

local function _resolve_ground_position(scene)
  assert(scene.ground ~= nil, "missing board_scene.ground")
  assert(scene.ground.get_position ~= nil, "missing board_scene.ground.get_position")
  local ground_pos = scene.ground.get_position()
  assert(ground_pos ~= nil and ground_pos.y ~= nil, "missing ground position")
  return ground_pos
end

local function _resolve_min_ground_offset()
  local board_cfg = board_geometry or {}
  local offset = board_cfg.player_min_ground_offset
  if offset == nil then
    return 0.5
  end
  return offset
end

function geometry.resolve_min_player_y(scene)
  local ground_pos = _resolve_ground_position(scene)
  return ground_pos.y + _resolve_min_ground_offset()
end

local function _occupant_count(list)
  return list and #list or 1
end

function geometry.resolve_occupant_slot(list, pid)
  local count = _occupant_count(list)
  local slot = 1
  if list and count > 1 then
    for s = 1, count do
      if list[s] == pid then
        slot = s
        break
      end
    end
  end
  return slot, count
end

function geometry.calc_slot_offset(slot, count, spacing)
  if count <= 1 or spacing <= 0 then
    return 0.0, 0.0
  end
  local per_row = 0
  while per_row * per_row < count do
    per_row = per_row + 1
  end
  local row = math.floor((slot - 1) / per_row)
  local col = (slot - 1) % per_row
  local start = -(per_row - 1) * spacing * 0.5
  local ox = start + col * spacing
  local oz = start + row * spacing
  return ox, oz
end

function geometry.calc_y_offset(base_y, min_player_y)
  if base_y < min_player_y then
    return min_player_y - base_y
  end
  return 0
end

function geometry.resolve_target_position(base, y_offset, ox, oz)
  return base + math.Vector3(ox, y_offset, oz)
end

return geometry

--[[ mutate4lua-manifest
version=4
projectHash=32c58399baf07cda
scope.0.id=chunk:src/ui/render/board/placement_geometry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=74
scope.0.semanticHash=86490efe61422547
scope.1.id=function:_resolve_ground_position
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=12
scope.1.semanticHash=ffef01c207f3f2e0
scope.2.id=function:_resolve_min_ground_offset
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=21
scope.2.semanticHash=51fc2e1828e0a3fc
scope.3.id=function:geometry.resolve_min_player_y
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=26
scope.3.semanticHash=0a695187bcfaf98a
scope.4.id=function:_occupant_count
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=30
scope.4.semanticHash=7eec5dd69ab75ea8
scope.5.id=function:geometry.resolve_occupant_slot
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=44
scope.5.semanticHash=dce075e8d570b2af
scope.6.id=function:geometry.calc_slot_offset
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=60
scope.6.semanticHash=a44a538af5388823
scope.7.id=function:geometry.calc_y_offset
scope.7.kind=function
scope.7.startLine=62
scope.7.endLine=67
scope.7.semanticHash=95f3b7bf7c2f630b
scope.8.id=function:geometry.resolve_target_position
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=71
scope.8.semanticHash=d50856449e530b4f
]]
