local logger = require("src.foundation.log.logger")
local runtime_state = require("src.ui.state.runtime")
local ui_event_intents = require("src.ui.input.event_intents")
local nodes = require("src.ui.schema.market")

local intents = {}
local VEHICLE_TAB_ENABLED = false

local function _market_log(...)
  if type(logger.info_unlimited) == "function" then
    logger.info_unlimited("[MarketDebug]", ...)
    return
  end
  logger.info("[MarketDebug]", ...)
end

local function _log_route_state(state, label, market, extra)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  if extra ~= nil then
    _market_log(
      label,
      "choice_id=" .. tostring(market and market.choice_id or nil),
      "active_tab=" .. tostring(market and market.active_tab or nil),
      "page_index=" .. tostring(market and market.page_index or nil),
      "page_count=" .. tostring(market and market.page_count or nil),
      "selected_option_id=" .. tostring(ui_runtime.pending_choice_selected_option_id),
      extra
    )
    return
  end
  _market_log(
    label,
    "choice_id=" .. tostring(market and market.choice_id or nil),
    "active_tab=" .. tostring(market and market.active_tab or nil),
    "page_index=" .. tostring(market and market.page_index or nil),
    "page_count=" .. tostring(market and market.page_count or nil),
    "selected_option_id=" .. tostring(ui_runtime.pending_choice_selected_option_id)
  )
end

local function _resolve_market(state, warn_label)
  local current_model = runtime_state.get_ui_model(state)
  local market = current_model and current_model.market or nil
  if not market then
    logger.warn("[MarketDebug] " .. tostring(warn_label) .. " missing market model")
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
        _log_route_state(state, "market_select click", market, "node=" .. tostring(name) .. ", index=" .. tostring(index))
        local option_id = ui_event_intents.resolve_option_id(market, { index = index }, state)
        if not option_id then
          logger.warn("[MarketDebug] market_select missing option:", tostring(index))
          return nil
        end
        _log_route_state(
          state,
          "market_select built",
          market,
          "node=" .. tostring(name) .. ", index=" .. tostring(index) .. ", option_id=" .. tostring(option_id)
        )
        return { type = "market_select", option_id = option_id }
      end,
    }
  end
  return specs
end

function intents.build_controls(state)
  local function _build_cancel_intent(node_name)
    local market = _resolve_market(state, "market_close")
    _log_route_state(state, "market_close click", market, "node=" .. tostring(node_name))
    local intent = ui_event_intents.choice_cancel_intent(state, "market_close")
    _log_route_state(
      state,
      intent and "market_close built" or "market_close build_nil",
      market,
      "node=" .. tostring(node_name) .. ", choice_id=" .. tostring(intent and intent.choice_id or nil)
    )
    return intent
  end

  local specs = {
    {
      name = nodes.confirm,
      build_intent = function()
        local market = _resolve_market(state, "market_confirm")
        if not market then return nil end
        _log_route_state(state, "market_confirm click", market, "node=" .. tostring(nodes.confirm))
        local ui_runtime = runtime_state.ensure_ui_runtime(state)
        local option_id = ui_runtime.pending_choice_selected_option_id
        if not option_id then
          logger.warn("[MarketDebug] market_confirm missing selected option")
          return nil
        end
        _log_route_state(
          state,
          "market_confirm built",
          market,
          "node=" .. tostring(nodes.confirm) .. ", option_id=" .. tostring(option_id)
        )
        return { type = "market_confirm", choice_id = market.choice_id, option_id = option_id }
      end,
    },
    {
      name = nodes.cancel,
      build_intent = function()
        return _build_cancel_intent(nodes.cancel)
      end,
    },
    {
      name = nodes.close,
      build_intent = function()
        return _build_cancel_intent(nodes.close)
      end,
    },
    {
      name = nodes.page_prev,
      build_intent = function()
        local market = _resolve_market(state, "market_page_prev")
        if not market then return nil end
        _log_route_state(state, "market_page_prev click", market, "node=" .. tostring(nodes.page_prev))
        _log_route_state(state, "market_page_prev built", market, "node=" .. tostring(nodes.page_prev))
        return { type = "market_page_prev", choice_id = market.choice_id }
      end,
    },
    {
      name = nodes.page_next,
      build_intent = function()
        local market = _resolve_market(state, "market_page_next")
        if not market then return nil end
        _log_route_state(state, "market_page_next click", market, "node=" .. tostring(nodes.page_next))
        _log_route_state(state, "market_page_next built", market, "node=" .. tostring(nodes.page_next))
        return { type = "market_page_next", choice_id = market.choice_id }
      end,
    },
    {
      name = nodes.tab_item,
      build_intent = function()
        local market = _resolve_market(state, "market_tab_select")
        if not market then return nil end
        _log_route_state(state, "market_tab_item click", market, "node=" .. tostring(nodes.tab_item))
        _log_route_state(state, "market_tab_item built", market, "node=" .. tostring(nodes.tab_item) .. ", tab=item")
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "item" }
      end,
    },
    {
      name = nodes.tab_skin,
      build_intent = function()
        local market = _resolve_market(state, "market_tab_select")
        if not market then return nil end
        _log_route_state(state, "market_tab_skin click", market, "node=" .. tostring(nodes.tab_skin))
        _log_route_state(state, "market_tab_skin built", market, "node=" .. tostring(nodes.tab_skin) .. ", tab=skin")
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "skin" }
      end,
    },
    {
      name = nodes.tab_vehicle,
      build_intent = function()
        if not VEHICLE_TAB_ENABLED then
          _market_log("market_tab_vehicle disabled", "node=" .. tostring(nodes.tab_vehicle))
          return nil
        end
        local market = _resolve_market(state, "market_tab_select")
        if not market then return nil end
        _log_route_state(state, "market_tab_vehicle click", market, "node=" .. tostring(nodes.tab_vehicle))
        _log_route_state(state, "market_tab_vehicle built", market, "node=" .. tostring(nodes.tab_vehicle) .. ", tab=vehicle")
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "vehicle" }
      end,
    },
  }
  return specs
end

return intents
