local board_view = require("src.ui.render.board")
local popup_presenter = require("src.ui.coord.popup_presenter")
local tip_queue = require("src.foundation.tips")

local state_callback_ports = {}

function state_callback_ports.install(state, get_current_game)
  state.push_popup = function(_, payload, opts)
    local ok = popup_presenter.push_popup(state, payload, opts)
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
    return tip_queue.enqueue(intent) == true
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
version=4
projectHash=44091e84c92325cc
scope.0.id=chunk:src/ui/ports/callbacks.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=42
scope.0.semanticHash=0b43d8e2bff4451c
scope.1.id=function:state_callback_ports.install
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=39
scope.1.semanticHash=b85cd46ab76be1bd
scope.2.id=function:state.push_popup
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=19
scope.2.semanticHash=8f43b5e154d5e5a8
scope.3.id=function:state.show_tip
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=26
scope.3.semanticHash=b49392e0deb60b8a
scope.4.id=function:state.on_tile_upgraded
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=30
scope.4.semanticHash=2fc68b1d0ce722c8
scope.5.id=function:state.on_tile_owner_changed
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=34
scope.5.semanticHash=2fc68b1d0ce722c8
scope.6.id=function:state.on_board_visual_sync
scope.6.kind=function
scope.6.startLine=36
scope.6.endLine=38
scope.6.semanticHash=aba9250a8c6b104f
]]
