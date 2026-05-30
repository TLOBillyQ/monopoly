local state_ports = {}

function state_ports.build()
  return {
    apply_role_control_lock = function(state, enabled)
      local ui_view = require("src.ui.coord.ui_runtime")
      ui_view.apply_role_control_lock(state, enabled)
    end,
    install_event_handlers = function(game, log, state)
      local event_handlers = require("src.ui.coord.event_handlers")
      event_handlers.install(game, log, state)
    end,
    on_bankruptcy_tiles_cleared = function(game, _, owned_tile_ids)
      local state = game and game.landing_visual_hold_state or nil
      if state and type(state.on_board_visual_sync) == "function" then
        return state:on_board_visual_sync({
          tile_ids = owned_tile_ids,
        }) == true
      end
      return false
    end,
  }
end

return state_ports

--[[ mutate4lua-manifest
version=2
projectHash=5f8f08875ddcdbfc
scope.0.id=chunk:src/ui/ports/state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=26
scope.0.semanticHash=ac5eb68fb91db6ab
scope.1.id=function:anonymous@5:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=8
scope.1.semanticHash=e9e510d89ca01b75
scope.2.id=function:anonymous@9:9
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=12
scope.2.semanticHash=558905b7e20be7d6
scope.3.id=function:anonymous@13:13
scope.3.kind=function
scope.3.startLine=13
scope.3.endLine=21
scope.3.semanticHash=6b9c91a4b674e914
scope.4.id=function:state_ports.build:3
scope.4.kind=function
scope.4.startLine=3
scope.4.endLine=23
scope.4.semanticHash=876ec8a6b9f74af5
]]
