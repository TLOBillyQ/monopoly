local M = {}

function M.build()
  return {
    apply_role_control_lock = function(state, enabled)
      local ui_view = require("src.presentation.api.UIViewService")
      ui_view.apply_role_control_lock(state, enabled)
    end,
    install_event_handlers = function(game, log, state)
      local event_handlers = require("src.presentation.api.UIEventHandlers")
      event_handlers.install(game, log, state)
    end,
    on_bankruptcy_tiles_cleared = function(game, _, owned_tile_ids)
      local ui_port = game and game.ui_port or nil
      local scene = ui_port and ui_port.board_scene or nil
      if not scene or not scene.building_unit_groups or not scene.tiles then
        return
      end
      local tile_renderer = require("src.presentation.render.TileRenderer")
      for _, tile_id in ipairs(owned_tile_ids or {}) do
        local idx = game.board:index_of_tile_id(tile_id)
        local building = scene.building_unit_groups[idx]
        if building then
          GameAPI.destroy_unit_with_children(building, true)
          scene.building_unit_groups[idx] = nil
        end
        local building_txt = scene.building_txt and scene.building_txt[idx] or nil
        if building_txt and building_txt.set_billboard_text then
          building_txt.set_billboard_text("  ")
        end
        local tile_unit = scene.tiles[idx]
        if tile_unit then
          tile_renderer.render_tile(tile_unit, tile_id, nil)
        end
      end
    end,
  }
end

return M
