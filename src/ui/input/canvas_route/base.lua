local base_nodes = require("src.ui.schema.base")
local event_intents = require("src.ui.input.event_intents")
local runtime_state = require("src.ui.state.runtime")

local intents = {}

function intents.build(state)
  return {
    {
      name = base_nodes.action_button,
      build_intent = function()
        local current_model = runtime_state.get_ui_model(state)
        local choice = current_model and current_model.choice or nil
        if choice and choice.kind == "item_phase_passive" then
          return event_intents.choice_cancel_intent(state, "action_button_passive")
        end
        return { type = "ui_button", id = "next" }
      end,
    },
    {
      name = base_nodes.auto_button,
      build_intent = function()
        return { type = "ui_button", id = "auto" }
      end,
    },
    {
      name = base_nodes.action_log_button,
      build_intent = function()
        return { type = "toggle_action_log" }
      end,
    },
    {
      name = base_nodes.skin_button,
      build_intent = function()
        return { type = "open_skin_panel" }
      end,
    },
    {
      name = base_nodes.gallery_button,
      build_intent = function()
        return { type = "open_gallery_panel" }
      end,
    },
  }
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=fcfdb43cdf02f02e
scope.0.id=chunk:src/ui/input/canvas_route/base.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=48
scope.0.semanticHash=2978d7df051da1d0
scope.1.id=function:anonymous@11:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=18
scope.1.semanticHash=52fa97ad852a9e98
scope.2.id=function:anonymous@22:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=24
scope.2.semanticHash=98465a34b6303c64
scope.3.id=function:anonymous@28:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=30
scope.3.semanticHash=aaad7996612b6854
scope.4.id=function:anonymous@34:34
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=36
scope.4.semanticHash=5d44a8e2cf071725
scope.5.id=function:anonymous@40:40
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=42
scope.5.semanticHash=4480c2ab536e2c06
scope.6.id=function:intents.build:7
scope.6.kind=function
scope.6.startLine=7
scope.6.endLine=45
scope.6.semanticHash=b93a43ca3a491dc6
]]
