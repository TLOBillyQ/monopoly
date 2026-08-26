local modal = require("src.ui.coord.modal")
local popup_presenter = require("src.ui.coord.popup_presenter")
local secondary_confirm_screen = require("src.ui.screens.secondary_confirm")

local modal_ports = {}

function modal_ports.build()
  return {
    close_choice_modal = function(state)
      modal.close_choice_modal(state)
    end,
    open_choice_modal = function(state, choice, market)
      modal.open_choice_modal(state, choice, market)
    end,
    open_pre_confirm_screen = function(state, choice, option_id, title, body)
      secondary_confirm_screen.open_pre_confirm(state, choice, option_id, title, body)
    end,
    close_popup = function(state)
      popup_presenter.close_popup(state)
    end,
  }
end

return modal_ports

--[[ mutate4lua-manifest
version=4
projectHash=7a63472ded53a2d3
scope.0.id=chunk:src/ui/ports/modal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=25
scope.0.semanticHash=036d87d3d6842f91
scope.1.id=function:modal_ports.build
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=22
scope.1.semanticHash=28b5c6b6b591e0c0
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=11
scope.2.semanticHash=c772a22f8680e278
scope.3.id=function:<anonymous>#2
scope.3.kind=function
scope.3.startLine=12
scope.3.endLine=14
scope.3.semanticHash=2fc68b1d0ce722c8
scope.4.id=function:<anonymous>#3
scope.4.kind=function
scope.4.startLine=15
scope.4.endLine=17
scope.4.semanticHash=3587ef533d740038
scope.5.id=function:<anonymous>#4
scope.5.kind=function
scope.5.startLine=18
scope.5.endLine=20
scope.5.semanticHash=c772a22f8680e278
]]
