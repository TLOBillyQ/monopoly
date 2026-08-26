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
version=4
projectHash=77916d57e82a7680
scope.0.id=chunk:src/ui/ports/state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=26
scope.0.semanticHash=37141e7eb5f7d56a
scope.1.id=function:state_ports.build
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=23
scope.1.semanticHash=ac0950ca78003682
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=5
scope.2.endLine=8
scope.2.semanticHash=7f98512d4f699fb5
scope.3.id=function:<anonymous>#2
scope.3.kind=function
scope.3.startLine=9
scope.3.endLine=12
scope.3.semanticHash=0fbe8c6ef37bc659
scope.4.id=function:<anonymous>#3
scope.4.kind=function
scope.4.startLine=13
scope.4.endLine=21
scope.4.semanticHash=feeb663205da6826
]]
