local base_nodes = require("src.ui.schema.base")
local route_model = require("src.ui.input.route_model")
local choice_support = require("src.ui.view.choice_support")
local optional_action_completion = require("src.turn.optional_action_completion")
local panel_interrupt = require("src.ui.coord.panel_interrupt")

local intents = {}

local function _input_blocked(state)
  local ui = state and state.ui
  if ui and ui.input_blocked == true then
    return true
  end
  return panel_interrupt.settlement_type(ui) ~= nil
end

local function _can_build_optional_completion_intent(state)
  local result = optional_action_completion.can_complete_optional_action_phase(nil, nil, state, {
    choice = route_model.choice(state),
    require_actor = false,
    gate_state = {
      input_blocked = _input_blocked(state),
    },
  })
  return result.ok == true
end

function intents.build(state)
  return {
    {
      name = base_nodes.action_button,
      build_intent = function()
        if choice_support.is_optional_action_choice(route_model.choice(state)) then
          return nil
        end
        return { type = "ui_button", id = "next" }
      end,
    },
    {
      name = base_nodes.end_button,
      build_intent = function()
        if not _can_build_optional_completion_intent(state) then
          return nil
        end
        return { type = "complete_optional_action_phase" }
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
projectHash=eb6d096e3a0d76be
scope.0.id=chunk:src/ui/input/route_base.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=71
scope.0.semanticHash=63ed4e02e523d37c
scope.1.id=function:_input_blocked:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=d4f49351597d456e
scope.2.id=function:_can_build_optional_completion_intent:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=21
scope.2.semanticHash=c6bbdf9fc1727b24
scope.3.id=function:anonymous@27:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=32
scope.3.semanticHash=3693104bc151a584
scope.4.id=function:anonymous@36:36
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=41
scope.4.semanticHash=28a2762d01f381ff
scope.5.id=function:anonymous@45:45
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=47
scope.5.semanticHash=98465a34b6303c64
scope.6.id=function:anonymous@51:51
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=53
scope.6.semanticHash=aaad7996612b6854
scope.7.id=function:anonymous@57:57
scope.7.kind=function
scope.7.startLine=57
scope.7.endLine=59
scope.7.semanticHash=5d44a8e2cf071725
scope.8.id=function:anonymous@63:63
scope.8.kind=function
scope.8.startLine=63
scope.8.endLine=65
scope.8.semanticHash=4480c2ab536e2c06
scope.9.id=function:intents.build:23
scope.9.kind=function
scope.9.startLine=23
scope.9.endLine=68
scope.9.semanticHash=f37a56a7cbdd2175
]]
