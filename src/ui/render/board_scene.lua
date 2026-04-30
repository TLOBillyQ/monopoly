local board_scene = {}
local runtime_ports = require("src.foundation.ports.runtime_ports")

local function _new_scene()
  return {
    building_unit_groups = {},
    units_by_player_id = {},
    target_pick = {
      tile_index_by_unit_id = {},
      marker_unit_id = nil,
      arrow_unit = nil,
    },
  }
end

local function _bind_player_units(scene, players)
  for i, player in ipairs(players) do
    local player_id = assert(player.id, "missing player id: " .. tostring(i))
    local role = runtime_ports.resolve_role(player_id)
    assert(role ~= nil, "missing role: " .. tostring(player_id))
    assert(role.get_ctrl_unit ~= nil, "missing role.get_ctrl_unit: " .. tostring(player_id))
    scene.units_by_player_id[player_id] = role.get_ctrl_unit()
  end
end

local function _resolve_tile_ids(map_cfg)
  local tile_ids = assert(map_cfg.path, "missing map path")
  if #tile_ids > 0 then
    return tile_ids
  end
  for i = 1, 45 do
    tile_ids[i] = i
  end
  return tile_ids
end

local function _build_unit_names(tile_ids)
  local tile_names = {}
  local building_names = {}
  for i, tile_id in ipairs(tile_ids) do
    tile_names[i] = "t" .. tostring(tile_id)
    building_names[i] = "b" .. tostring(tile_id)
  end
  return tile_names, building_names
end

local function _bind_tile_target_index(scene, tile, index)
  if not (LuaAPI and type(LuaAPI.get_unit_id) == "function") then
    return
  end
  local ok_id, tile_unit_id = pcall(LuaAPI.get_unit_id, tile)
  if ok_id and tile_unit_id ~= nil then
    scene.target_pick.tile_index_by_unit_id[tile_unit_id] = index
  end
end

local function _bind_building(scene, building, index)
  if building == nil then
    return
  end
  building.set_physics_active(false)
  local txt = building.get_child_by_name("txt")
  scene.building_txt[index] = txt
  txt.set_billboard_text("  ")
end

local function _bind_tiles_and_buildings(scene, tile_ids)
  local tile_names, building_names = _build_unit_names(tile_ids)
  scene.tiles = LuaAPI.query_units(tile_names)
  scene.buildings = LuaAPI.query_units(building_names)
  scene.building_txt = {}
  for i = 1, #tile_ids do
    local tile = scene.tiles[i]
    tile.set_physics_active(false)
    _bind_tile_target_index(scene, tile, i)
    _bind_building(scene, scene.buildings[i], i)
  end
end

local function _hide_unit(unit)
  if unit ~= nil and type(unit.set_model_visible) == "function" then
    unit.set_model_visible(false)
  end
end

local function _bind_target_marker(scene)
  if not (LuaAPI and type(LuaAPI.query_unit) == "function") then
    return
  end
  local marker = LuaAPI.query_unit("可选择地块")
  if marker ~= nil and type(LuaAPI.get_unit_id) == "function" then
    local ok_marker_id, marker_unit_id = pcall(LuaAPI.get_unit_id, marker)
    if ok_marker_id then
      scene.target_pick.marker_unit_id = marker_unit_id
    end
  end
  _hide_unit(marker)
  local arrow = LuaAPI.query_unit("选择地块箭头")
  scene.target_pick.arrow_unit = arrow
  _hide_unit(arrow)
end

local function _bind_ground(scene)
  scene.ground = LuaAPI.query_unit("ground")
  assert(scene.ground ~= nil, "missing ground unit")
  assert(scene.ground.set_model_visible ~= nil, "missing ground.set_model_visible")
  scene.ground.set_model_visible(false)
end

function board_scene.init(state, map_cfg, game)
  assert(state ~= nil, "missing state")
  assert(map_cfg ~= nil, "missing map_cfg")
  assert(game ~= nil and game.players ~= nil, "missing game.players")

  local scene = _new_scene()
  _bind_player_units(scene, game.players)
  _bind_tiles_and_buildings(scene, _resolve_tile_ids(map_cfg))
  _bind_target_marker(scene)
  _bind_ground(scene)

  state.board_scene = scene
  return scene
end

return board_scene
