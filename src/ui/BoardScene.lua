local board_scene = {}

function board_scene.init(state, map_cfg)
  assert(state ~= nil, "missing state")
  assert(map_cfg ~= nil, "missing map_cfg")

  local scene = {
    building_unit_groups = {},
    units_by_player_id = {},
  }

  local roles = {
    GameAPI.get_role(1),
    GameAPI.get_role(2),
    GameAPI.get_role(3),
    GameAPI.get_role(4),
  }
  for i, role in ipairs(roles) do
    assert(role ~= nil, "missing role: " .. tostring(i))
    assert(role.get_ctrl_unit ~= nil, "missing role.get_ctrl_unit: " .. tostring(i))
    scene.units_by_player_id[i] = role.get_ctrl_unit()
  end

  local first_unit = scene.units_by_player_id[1]
  assert(first_unit ~= nil, "missing first unit")
  assert(first_unit.add_state ~= nil, "missing unit.add_state")
  assert(Enums ~= nil and Enums.BuffState ~= nil, "missing Enums.BuffState")
  for _ = 1, #roles do
    first_unit.add_state(Enums.BuffState.BUFF_FORBID_CONTROL)
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
   for i = 1, 45 do
      scene.tiles[i].set_physics_active(false)
      scene.buildings[i].set_physics_active(false)
    end

  scene.ground = LuaAPI.query_unit("ground")
  assert(scene.ground ~= nil, "missing ground unit")
  assert(scene.ground.set_model_visible ~= nil, "missing ground.set_model_visible")
  scene.ground.set_model_visible(false)

  state.board_scene = scene
  return scene
end

return board_scene
