local logger = require("src.core.utils.logger")
local runtime_state = require("src.ui.state")
local ui_event_intents = require("src.ui.input.event_intents")
local nodes = require("src.ui.schema.market_nodes")

local intents = {}
local VEHICLE_TAB_ENABLED = false

local function _resolve_market(state, warn_label)
  local current_model = runtime_state.get_ui_model(state)
  local market = current_model and current_model.market or nil
  if not market then
    return nil
  end
  return market
end

function intents.build_items(state)
  local specs = {}
  for index, name in ipairs(nodes.item_buttons or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local market = _resolve_market(state, "market_select")
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
        local market = _resolve_market(state, "market_confirm")
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
        local market = _resolve_market(state, "market_page_prev")
        if not market then return nil end
        return { type = "market_page_prev", choice_id = market.choice_id }
      end,
    },
    {
      name = nodes.page_next,
      build_intent = function()
        local market = _resolve_market(state, "market_page_next")
        if not market then return nil end
        return { type = "market_page_next", choice_id = market.choice_id }
      end,
    },
    {
      name = nodes.tab_item,
      build_intent = function()
        local market = _resolve_market(state, "market_tab_select")
        if not market then return nil end
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "item" }
      end,
    },
    {
      name = nodes.tab_skin,
      build_intent = function()
        local market = _resolve_market(state, "market_tab_select")
        if not market then return nil end
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "skin" }
      end,
    },
    {
      name = nodes.tab_vehicle,
      build_intent = function()
        if not VEHICLE_TAB_ENABLED then
          return nil
        end
        local market = _resolve_market(state, "market_tab_select")
        if not market then return nil end
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "vehicle" }
      end,
    },
  }
  return specs
end

return intents
