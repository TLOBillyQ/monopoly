local logger = require("src.core.Logger")
local ui_event_intents = require("src.presentation.interaction.UIEventIntents")
local nodes = require("src.presentation.canvas.market.nodes")

local intents = {}
local VEHICLE_TAB_ENABLED = false

local function _resolve_market(state, warn_label)
  local market = state.ui_model and state.ui_model.market or nil
  if not market then
    logger.warn(warn_label .. " without market")
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
          logger.warn("market_select missing option:", tostring(index))
          return nil
        end
        return { type = "market_select", option_id = option_id }
      end,
    }
  end
  return specs
end

function intents.build_controls(state)
  local specs = {
    {
      name = nodes.confirm,
      build_intent = function()
        local market = _resolve_market(state, "market_confirm")
        if not market then return nil end
        local option_id = state.pending_choice_selected_option_id
        if not option_id then
          logger.warn("market_confirm missing selected option")
          return nil
        end
        return { type = "market_confirm", choice_id = market.choice_id, option_id = option_id }
      end,
    },
    {
      name = nodes.close,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "market_close")
      end,
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
