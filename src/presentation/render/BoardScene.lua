local board_scene = {}
local runtime_ports = require("src.core.RuntimePorts")

function board_scene.init(state, map_cfg, game)
  assert(state ~= nil, "missing state")
  assert(map_cfg ~= nil, "missing map_cfg")
  assert(game ~= nil and game.players ~= nil, "missing game.players")

  local scene = {
    building_unit_groups = {},
    units_by_player_id = {},
    target_pick = {
      tile_index_by_unit_id = {},
      marker_unit_id = nil,
      arrow_unit = nil,
    },
  }

  for i, player in ipairs(game.players) do
    local player_id = assert(player.id, "missing player id: " .. tostring(i))
    local role = runtime_ports.resolve_role(player_id)
    assert(role ~= nil, "missing role: " .. tostring(player_id))
    assert(role.get_ctrl_unit ~= nil, "missing role.get_ctrl_unit: " .. tostring(player_id))
    local unit = role.get_ctrl_unit()
    scene.units_by_player_id[player_id] = unit
  end

  local tile_names = {}
  local building_names = {}
  local tile_ids = assert(map_cfg.path, "missing map path")
  if #tile_ids == 0 then
    for i = 1, 45 do
      tile_ids[i] = i
    end
  end
  for i, tile_id in ipairs(tile_ids) do
    tile_names[i] = "t" .. tostring(tile_id)
    building_names[i] = "b" .. tostring(tile_id)
  end
  scene.tiles = LuaAPI.query_units(tile_names)
  scene.buildings = LuaAPI.query_units(building_names)
  scene.building_txt = {}
  for i = 1, #tile_ids do
    local tile = scene.tiles[i]
    tile.set_physics_active(false)
    if LuaAPI and type(LuaAPI.get_unit_id) == "function" then
      local ok_id, tile_unit_id = pcall(LuaAPI.get_unit_id, tile)
      if ok_id and tile_unit_id ~= nil then
        scene.target_pick.tile_index_by_unit_id[tile_unit_id] = i
      end
    end
    local b = scene.buildings[i]
    if b ~= nil then
      b.set_physics_active(false)
      local txt = b.get_child_by_name("txt")
      scene.building_txt[i] = txt
      txt.set_billboard_text("  ")
    end
  end

  if LuaAPI and type(LuaAPI.query_unit) == "function" then
    local marker = LuaAPI.query_unit("可选择地块")
    if marker ~= nil and type(LuaAPI.get_unit_id) == "function" then
      local ok_marker_id, marker_unit_id = pcall(LuaAPI.get_unit_id, marker)
      if ok_marker_id then
        scene.target_pick.marker_unit_id = marker_unit_id
      end
      if type(marker.set_model_visible) == "function" then
        marker.set_model_visible(false)
      end
    end
    local arrow = LuaAPI.query_unit("选择地块箭头")
    if arrow ~= nil then
      scene.target_pick.arrow_unit = arrow
      if type(arrow.set_model_visible) == "function" then
        arrow.set_model_visible(false)
      end
    end
  end

  scene.ground = LuaAPI.query_unit("ground")
  assert(scene.ground ~= nil, "missing ground unit")
  assert(scene.ground.set_model_visible ~= nil, "missing ground.set_model_visible")
  scene.ground.set_model_visible(false)

  state.board_scene = scene
  return scene
end

return board_scene
