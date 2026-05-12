local logger = require("src.foundation.log.logger")
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
          logger.warn("[MarketDebug] market_select missing option:", tostring(index))
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

  local specs = {
    {
      name = nodes.confirm,
      build_intent = function()
        local market = _resolve_market(state)
        if not market then return nil end
        local ui_runtime = runtime_state.ensure_ui_runtime(state)
        local option_id = ui_runtime.pending_choice_selected_option_id
        if not option_id then
          logger.warn("[MarketDebug] market_confirm missing selected option")
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
      build_intent = function()
        local market = _resolve_market(state)
        if not market then return nil end
        return { type = "market_page_prev", choice_id = market.choice_id }
      end,
    },
    {
      name = nodes.page_next,
      build_intent = function()
        local market = _resolve_market(state)
        if not market then return nil end
        return { type = "market_page_next", choice_id = market.choice_id }
      end,
    },
    {
      name = nodes.tab_item,
      build_intent = function()
        local market = _resolve_market(state)
        if not market then return nil end
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "item" }
      end,
    },
    {
      name = nodes.tab_skin,
      build_intent = function()
        local market = _resolve_market(state)
        if not market then return nil end
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "skin" }
      end,
    },
  }
  return specs
end

return intents
