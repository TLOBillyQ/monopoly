local logger = require("src.foundation.log.logger")
local runtime_state = require("src.ui.state.runtime")
local ui_event_intents = require("src.ui.input.event_intents")
local nodes = require("src.ui.schema.market")

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

local function _format_visible_option_ids(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  local visible = ui_runtime and ui_runtime.choice_visible_option_ids
  if type(visible) ~= "table" then
    return tostring(visible)
  end
  local ids = {}
  for index = 1, 16 do
    local value = visible[index]
    if value == nil then
      break
    end
    ids[#ids + 1] = tostring(value)
  end
  return "[" .. table.concat(ids, ",") .. "]"
end

local function _format_market_options(market)
  local options = market and market.options
  if type(options) ~= "table" then
    return tostring(options)
  end
  local ids = {}
  for _, opt in ipairs(options) do
    ids[#ids + 1] = tostring(type(opt) == "table" and opt.id or opt)
  end
  return "[" .. table.concat(ids, ",") .. "]"
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
        logger.warn(
          "[MarketDebug] market_select click:",
          "index=" .. tostring(index),
          "resolved=" .. tostring(option_id),
          "tab=" .. tostring(market.active_tab),
          "page=" .. tostring(market.page_index),
          "visible=" .. _format_visible_option_ids(state),
          "market_options=" .. _format_market_options(market)
        )
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
        logger.warn(
          "[MarketDebug] market_confirm click:",
          "selected=" .. tostring(option_id),
          "choice_id=" .. tostring(market.choice_id),
          "tab=" .. tostring(market.active_tab),
          "page=" .. tostring(market.page_index),
          "visible=" .. _format_visible_option_ids(state),
          "market_options=" .. _format_market_options(market)
        )
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
        logger.warn("[MarketDebug] market_page_prev click:",
          "tab=" .. tostring(market.active_tab),
          "page=" .. tostring(market.page_index))
        return { type = "market_page_prev", choice_id = market.choice_id }
      end,
    },
    {
      name = nodes.page_next,
      build_intent = function()
        local market = _resolve_market(state, "market_page_next")
        if not market then return nil end
        logger.warn("[MarketDebug] market_page_next click:",
          "tab=" .. tostring(market.active_tab),
          "page=" .. tostring(market.page_index))
        return { type = "market_page_next", choice_id = market.choice_id }
      end,
    },
    {
      name = nodes.tab_item,
      build_intent = function()
        local market = _resolve_market(state, "market_tab_select")
        if not market then return nil end
        logger.warn("[MarketDebug] market_tab_select click: tab=item",
          "from_tab=" .. tostring(market.active_tab))
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "item" }
      end,
    },
    {
      name = nodes.tab_skin,
      build_intent = function()
        local market = _resolve_market(state, "market_tab_select")
        if not market then return nil end
        logger.warn("[MarketDebug] market_tab_select click: tab=skin",
          "from_tab=" .. tostring(market.active_tab))
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
