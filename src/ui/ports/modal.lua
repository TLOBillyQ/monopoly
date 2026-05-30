local modal = require("src.ui.coord.modal")
local choice_openers = require("src.ui.coord.choice_openers")

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
      choice_openers.open_pre_confirm_screen(state, choice, option_id, title, body)
    end,
    close_popup = function(state)
      modal.close_popup(state)
    end,
  }
end

return modal_ports

--[[ mutate4lua-manifest
version=2
projectHash=7bf757a9948c011f
scope.0.id=chunk:src/ui/ports/modal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=24
scope.0.semanticHash=1f264b4567a7bcb2
scope.1.id=function:anonymous@8:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=24aa6f6465109b37
scope.2.id=function:anonymous@11:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=9e61e00e1f79a867
scope.3.id=function:anonymous@14:14
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=16
scope.3.semanticHash=cbd3ac4d0cfae8e2
scope.4.id=function:anonymous@17:17
scope.4.kind=function
scope.4.startLine=17
scope.4.endLine=19
scope.4.semanticHash=d10bc40093bf8e6e
scope.5.id=function:modal_ports.build:6
scope.5.kind=function
scope.5.startLine=6
scope.5.endLine=21
scope.5.semanticHash=1575ad11ab40828e
]]
