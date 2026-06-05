local runtime_state = require("src.ui.state.runtime")
local ui_event_intents = require("src.ui.input.event_intents")
local nodes = require("src.ui.schema.market")

local intents = {}

local function _resolve_market(state)
  local current_model = runtime_state.get_ui_model(state)
  return current_model and current_model.market or nil
end

function intents.build_items(state)
  local specs = {}
  for index, name in ipairs(nodes.item_buttons or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local market = _resolve_market(state)
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
      local market = _resolve_market(state)
      if not market then return nil end
      return { type = intent_type, choice_id = market.choice_id }
    end
  end

  local specs = {
    {
      name = nodes.confirm,
      build_intent = function()
        local market = _resolve_market(state)
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
        local market = _resolve_market(state)
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
projectHash=fc9509b2c00017ec
scope.0.id=chunk:src/ui/input/route_market.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=87
scope.0.semanticHash=3e2f9719e399d2b9
scope.1.id=function:_resolve_market:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=10
scope.1.semanticHash=1c307517cc4ff3e7
scope.2.id=function:anonymous@17:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=25
scope.2.semanticHash=96f36120ac72328c
scope.3.id=function:_build_cancel_intent:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=34
scope.3.semanticHash=c5ec5db84650a9db
scope.4.id=function:anonymous@37:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=41
scope.4.semanticHash=193095b1fdc803df
scope.5.id=function:_build_choice_intent:36
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=42
scope.5.semanticHash=c809ee33a772a674
scope.6.id=function:anonymous@47:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=56
scope.6.semanticHash=4eca2bd6ea85d2f8
scope.7.id=function:anonymous@76:76
scope.7.kind=function
scope.7.startLine=76
scope.7.endLine=80
scope.7.semanticHash=7b395f037993a554
scope.8.id=function:intents.build_controls:31
scope.8.kind=function
scope.8.startLine=31
scope.8.endLine=84
scope.8.semanticHash=d21af96c5a9590f2
]]
