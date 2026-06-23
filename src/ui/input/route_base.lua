local base_nodes = require("src.ui.schema.base")
local event_intents = require("src.ui.input.event_intents")
local route_model = require("src.ui.input.route_model")
local choice_support = require("src.ui.view.choice_support")

local intents = {}

local function _input_blocked(state)
  return state and state.ui and state.ui.input_blocked == true
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
        if _input_blocked(state) then
          return nil
        end
        if not choice_support.is_cancelable_optional_action_choice(route_model.choice(state)) then
          return nil
        end
        return event_intents.choice_cancel_intent(state, "optional_action_end")
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
projectHash=26b13979b51ad031
scope.0.id=chunk:src/ui/input/route_base.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=63
scope.0.semanticHash=f470095be6f1345f
scope.0.lastMutatedAt=2026-06-23T03:14:49Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
scope.1.id=function:_input_blocked:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=d4f49351597d456e
scope.1.lastMutatedAt=2026-06-23T03:14:49Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:anonymous@16:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=21
scope.2.semanticHash=3693104bc151a584
scope.2.lastMutatedAt=2026-06-23T03:14:49Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=3
scope.2.lastMutationKilled=3
scope.3.id=function:anonymous@25:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=33
scope.3.semanticHash=96551ef9ccf09ba7
scope.3.lastMutatedAt=2026-06-23T03:14:49Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:anonymous@37:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=39
scope.4.semanticHash=98465a34b6303c64
scope.4.lastMutatedAt=2026-06-23T03:14:49Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=2
scope.4.lastMutationKilled=2
scope.5.id=function:anonymous@43:43
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=45
scope.5.semanticHash=aaad7996612b6854
scope.5.lastMutatedAt=2026-06-23T03:14:49Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
scope.6.id=function:anonymous@49:49
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=51
scope.6.semanticHash=5d44a8e2cf071725
scope.6.lastMutatedAt=2026-06-23T03:14:49Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:anonymous@55:55
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=57
scope.7.semanticHash=4480c2ab536e2c06
scope.7.lastMutatedAt=2026-06-23T03:14:49Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:intents.build:12
scope.8.kind=function
scope.8.startLine=12
scope.8.endLine=60
scope.8.semanticHash=60f0193805e00641
scope.8.lastMutatedAt=2026-06-23T03:14:08Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=no_sites
scope.8.lastMutationSites=0
scope.8.lastMutationKilled=0
]]
