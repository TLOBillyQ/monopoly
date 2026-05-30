local board_view = require("src.ui.render.board")
local modal = require("src.ui.coord.modal")
local host_bridge = require("src.ui.host_bridge")

local state_callback_ports = {}

function state_callback_ports.install(state, get_current_game)
  state.push_popup = function(_, payload, opts)
    local ok = modal.push_popup(state, payload, opts)
    if state.ui then
      local current_game = get_current_game()
      if ok and current_game and current_game.turn then
        state.ui.popup_owner_index = current_game.turn.current_player_index
      else
        state.ui.popup_owner_index = nil
      end
    end
    return ok
  end

  state.show_tip = function(_, intent)
    if type(intent) ~= "table" then
      return false
    end
    return host_bridge.enqueue_tip(intent) == true
  end

  state.on_tile_upgraded = function(_, tile_id, level)
    board_view.on_tile_upgraded(state, tile_id, level)
  end

  state.on_tile_owner_changed = function(_, tile_id, owner_id)
    board_view.on_tile_owner_changed(state, tile_id, owner_id)
  end

  state.on_board_visual_sync = function(_, payload)
    return board_view.sync_many(state, payload)
  end
end

return state_callback_ports

--[[ mutate4lua-manifest
version=2
projectHash=d2093bdebb676a0d
scope.0.id=chunk:src/ui/ports/callbacks.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=42
scope.0.semanticHash=8cb1ad5028a22f0c
scope.1.id=function:anonymous@8:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=19
scope.1.semanticHash=fe7474d6c7acea29
scope.2.id=function:anonymous@21:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=26
scope.2.semanticHash=085a2b847f3e6b57
scope.3.id=function:anonymous@28:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=30
scope.3.semanticHash=2ca0429471649059
scope.4.id=function:anonymous@32:32
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=34
scope.4.semanticHash=2bd8d01d78acd767
scope.5.id=function:anonymous@36:36
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=38
scope.5.semanticHash=8515cfcdbc517273
scope.6.id=function:state_callback_ports.install:7
scope.6.kind=function
scope.6.startLine=7
scope.6.endLine=39
scope.6.semanticHash=50f77b29d22911f1
]]
