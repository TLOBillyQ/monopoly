local ui_event_intents = require("src.ui.input.event_intents")
local route_model = require("src.ui.input.route_model")
local runtime_state = require("src.ui.state.runtime")
local nodes = require("src.ui.schema.market")

local intents = {}

function intents.build_items(state)
  local specs = {}
  for index, name in ipairs(nodes.item_buttons or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local market = route_model.market(state)
        if not market then return nil end
        local option_id = ui_event_intents.resolve_option_id(market, { index = index }, state)
        if not option_id then
          return nil
        end
        return { type = "market_select", option_id = option_id }
      end,
    }
  end
  return specs
end

function intents.build_controls(state)
  local function _build_cancel_intent()
    return ui_event_intents.choice_cancel_intent(state, "market_close")
  end

  local function _build_choice_intent(intent_type)
    return function()
      local market = route_model.market(state)
      if not market then return nil end
      return { type = intent_type, choice_id = market.choice_id }
    end
  end

  local specs = {
    {
      name = nodes.confirm,
      build_intent = function()
        local market = route_model.market(state)
        if not market then return nil end
        local ui_runtime = runtime_state.ensure_ui_runtime(state)
        local option_id = ui_runtime.pending_choice_selected_option_id
        if not option_id then
          return nil
        end
        return { type = "market_confirm", choice_id = market.choice_id, option_id = option_id }
      end,
    },
    {
      name = nodes.cancel,
      build_intent = _build_cancel_intent,
    },
    {
      name = nodes.close,
      build_intent = _build_cancel_intent,
    },
    {
      name = nodes.page_prev,
      build_intent = _build_choice_intent("market_page_prev"),
    },
    {
      name = nodes.page_next,
      build_intent = _build_choice_intent("market_page_next"),
    },
    {
      name = nodes.tab_item,
      build_intent = function()
        local market = route_model.market(state)
        if not market then return nil end
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "item" }
      end,
    },
  }
  return specs
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=1f19d6416c046deb
scope.0.id=chunk:src/ui/input/route_market.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=83
scope.0.semanticHash=fe569cf47f47489c
scope.0.lastMutatedAt=2026-06-23T03:24:21Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=7
scope.0.lastMutationKilled=7
scope.1.id=function:anonymous@13:13
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=21
scope.1.semanticHash=cd8f23e034a97281
scope.1.lastMutatedAt=2026-06-23T03:24:21Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_build_cancel_intent:28
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=30
scope.2.semanticHash=c5ec5db84650a9db
scope.2.lastMutatedAt=2026-06-23T03:24:21Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:anonymous@33:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=37
scope.3.semanticHash=5d8a8bf7a1a8f0da
scope.3.lastMutatedAt=2026-06-23T03:24:21Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
scope.4.id=function:_build_choice_intent:32
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=38
scope.4.semanticHash=b8cec245b6e11ab5
scope.4.lastMutatedAt=2026-06-23T03:24:21Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=no_sites
scope.4.lastMutationSites=0
scope.4.lastMutationKilled=0
scope.5.id=function:anonymous@43:43
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=52
scope.5.semanticHash=99c41dcb2e581fbd
scope.5.lastMutatedAt=2026-06-23T03:24:21Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=5
scope.5.lastMutationKilled=5
scope.6.id=function:anonymous@72:72
scope.6.kind=function
scope.6.startLine=72
scope.6.endLine=76
scope.6.semanticHash=36999b6f069a210f
scope.6.lastMutatedAt=2026-06-23T03:24:21Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=4
scope.6.lastMutationKilled=4
scope.7.id=function:intents.build_controls:27
scope.7.kind=function
scope.7.startLine=27
scope.7.endLine=80
scope.7.semanticHash=54bcd8fcc05a5141
scope.7.lastMutatedAt=2026-06-23T03:24:21Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=2
scope.7.lastMutationKilled=2
]]
