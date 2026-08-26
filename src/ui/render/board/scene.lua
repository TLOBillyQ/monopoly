local board_scene = {}
local runtime_ports = require("src.foundation.ports.runtime_ports")
local host_units = require("src.ui.seams.host_units")

local function _new_scene()
  return {
    building_unit_groups = {},
    units_by_player_id = {},
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
  scene.tiles = host_units.query_units(tile_names)
  scene.buildings = host_units.query_units(building_names)
  scene.building_txt = {}
  for i = 1, #tile_ids do
    local tile = scene.tiles[i]
    tile.set_physics_active(false)
    _bind_building(scene, scene.buildings[i], i)
  end
end

local function _bind_ground(scene)
  scene.ground = host_units.query_unit("ground")
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
  _bind_ground(scene)

  state.board_scene = scene
  return scene
end

return board_scene

--[[ mutate4lua-manifest
version=4
projectHash=2e13f51003dc49ed
scope.0.id=chunk:src/ui/render/board/scene.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=87
scope.0.semanticHash=dbbe9c20a59427e8
scope.1.id=function:_new_scene
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=f7c2452064857734
scope.2.id=function:_bind_player_units
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=20
scope.2.semanticHash=511e47540880d3d6
scope.3.id=function:_resolve_tile_ids
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=31
scope.3.semanticHash=6408c14fb1e2d849
scope.4.id=function:_build_unit_names
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=41
scope.4.semanticHash=caf5e9d97be928f3
scope.5.id=function:_bind_building
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=51
scope.5.semanticHash=aed9e02b19b151fb
scope.6.id=function:_bind_tiles_and_buildings
scope.6.kind=function
scope.6.startLine=53
scope.6.endLine=63
scope.6.semanticHash=ce96bc661b618780
scope.7.id=function:_bind_ground
scope.7.kind=function
scope.7.startLine=65
scope.7.endLine=70
scope.7.semanticHash=7386e1cf4362525e
scope.8.id=function:board_scene.init
scope.8.kind=function
scope.8.startLine=72
scope.8.endLine=84
scope.8.semanticHash=235e75948d6c6af7
]]
