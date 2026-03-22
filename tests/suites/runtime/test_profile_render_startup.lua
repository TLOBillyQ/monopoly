local support = require("support.test_profile_support")

local function _test_upgrade_build_marks_tile_render_called_for_startup_render()
  local game = support.apply_profile("upgrade_build")
  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
  local rendered_tile_ids = {}
  local rendered_building_tile_ids = {}

  support.with_patches({
    {
      target = tile_renderer,
      key = "render_tile",
      value = function(_, tile_id)
        rendered_tile_ids[#rendered_tile_ids + 1] = tile_id
        return true
      end,
    },
    {
      target = building_effects,
      key = "spawn_upgrade_building_units",
      value = function(_, _, building_index)
        local tile = game.board:get_tile(building_index)
        rendered_building_tile_ids[#rendered_building_tile_ids + 1] = tile and tile.id or nil
        return true
      end,
    },
  }, function()
    support.render_profile_startup(game)
  end)

  assert(rendered_tile_ids[1] == 1, "startup render should render configured tile")
  assert(#rendered_tile_ids == 1, "startup render should only render flagged tiles")
  assert(#rendered_building_tile_ids == 0, "level 0 tile should not spawn startup building render")
end

local function _test_strong_card_marks_tile_render_called_for_startup_render()
  local game = support.apply_profile("strong_card")
  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
  local rendered_tile_ids = {}
  local rendered_building_tile_ids = {}

  support.with_patches({
    {
      target = tile_renderer,
      key = "render_tile",
      value = function(_, tile_id)
        rendered_tile_ids[#rendered_tile_ids + 1] = tile_id
        return true
      end,
    },
    {
      target = building_effects,
      key = "spawn_upgrade_building_units",
      value = function(_, _, building_index)
        local tile = game.board:get_tile(building_index)
        rendered_building_tile_ids[#rendered_building_tile_ids + 1] = tile and tile.id or nil
        return true
      end,
    },
  }, function()
    support.render_profile_startup(game)
  end)

  assert(rendered_tile_ids[1] == 12, "startup render should render strong card staging target tile")
  assert(#rendered_tile_ids == 1, "startup render should only render flagged tile")
  assert(rendered_building_tile_ids[1] == 12, "startup render should spawn building for strong card staging target tile")
  assert(#rendered_building_tile_ids == 1, "startup render should only spawn flagged building")
end

local function _test_missile_marks_overlay_render_called_for_startup_render()
  local game = support.apply_profile("missile")
  local overlay_runtime = require("src.ui.render.anim_overlay_runtime")
  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
  local overlay_calls = {}
  local rendered_tile_ids = {}
  local rendered_building_tile_ids = {}

  support.with_patches({
    {
      target = overlay_runtime,
      key = "spawn_overlay",
      value = function(_, kind, tile_index)
        overlay_calls[#overlay_calls + 1] = { kind = kind, tile_index = tile_index }
        return true
      end,
    },
    {
      target = tile_renderer,
      key = "render_tile",
      value = function(_, tile_id)
        rendered_tile_ids[#rendered_tile_ids + 1] = tile_id
        return true
      end,
    },
    {
      target = building_effects,
      key = "spawn_upgrade_building_units",
      value = function(_, _, building_index)
        local tile = game.board:get_tile(building_index)
        rendered_building_tile_ids[#rendered_building_tile_ids + 1] = tile and tile.id or nil
        return true
      end,
    },
  }, function()
    support.render_profile_startup(game)
  end)

  local target_index = assert(game.board:index_of_tile_id(11), "missile staging target tile should exist in board path")
  assert(rendered_tile_ids[1] == 11, "startup render should render flagged tile before overlay")
  assert(#rendered_tile_ids == 1, "startup render should only render flagged tile")
  assert(rendered_building_tile_ids[1] == 11, "startup render should spawn building for flagged tile with level")
  assert(#rendered_building_tile_ids == 1, "startup render should only spawn flagged building")
  assert(#overlay_calls == 2, "startup render should spawn both flagged overlays")
  local kinds = {
    [overlay_calls[1].kind] = true,
    [overlay_calls[2].kind] = true,
  }
  local indices = {
    [overlay_calls[1].tile_index] = true,
    [overlay_calls[2].tile_index] = true,
  }
  assert(kinds.roadblock == true, "startup render should spawn roadblock overlay")
  assert(kinds.mine == true, "startup render should spawn mine overlay")
  assert(indices[target_index] == true, "startup overlay render should target configured tile index")
end

return {
  name = "runtime.test_profile_render_startup",
  tests = {
    { name = "upgrade_build_marks_tile_render_called_for_startup_render", run = _test_upgrade_build_marks_tile_render_called_for_startup_render },
    { name = "strong_card_marks_tile_render_called_for_startup_render", run = _test_strong_card_marks_tile_render_called_for_startup_render },
    { name = "missile_marks_overlay_render_called_for_startup_render", run = _test_missile_marks_overlay_render_called_for_startup_render },
  },
}
