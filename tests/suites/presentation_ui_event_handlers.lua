local support = require("TestSupport")
local _with_patches = support.with_patches
local number_utils = require("src.core.NumberUtils")
local monopoly_event = require("src.core.events.MonopolyEvents")
local host_runtime = require("src.presentation.api.HostRuntimePort")

local function _load_fresh_handlers()
  package.loaded["src.presentation.api.UIEventHandlers"] = nil
  return require("src.presentation.api.UIEventHandlers")
end

local function _test_market_buy_failed_shows_tip_for_at_least_one_second_and_pushes_popup()
  local handlers = {}
  local tips = {}
  local popups = {}

  _with_patches({
    {
      target = host_runtime,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = host_runtime,
      key = "show_tips",
      value = function(text, duration)
        tips[#tips + 1] = { text = text, duration = duration }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    local state = {
      push_popup = function(_, payload)
        popups[#popups + 1] = payload
      end,
    }
    event_handlers.install(nil, nil, state)
    local handler = handlers[monopoly_event.market.buy_failed]
    assert(type(handler) == "function", "buy_failed handler should be registered")
    handler(nil, nil, {
      popup = {
        title = "黑市",
        body = "余额不足",
      },
    })
  end)

  assert(#tips == 1, "buy_failed should emit exactly one tip")
  assert(tips[1].text == "余额不足", "tip text should use popup body when available")
  assert(number_utils.is_numeric(tips[1].duration), "tip duration should be numeric")
  assert(tips[1].duration >= 1.0, "tip duration should be at least 1 second")
  assert(#popups == 1, "buy_failed should still push popup")
  assert(popups[1].body == "余额不足", "popup body should stay unchanged")
end

local function _test_market_buy_failed_without_popup_body_uses_fallback_tip()
  local handlers = {}
  local tips = {}

  _with_patches({
    {
      target = host_runtime,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = host_runtime,
      key = "show_tips",
      value = function(text, duration)
        tips[#tips + 1] = { text = text, duration = duration }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {})
    local handler = handlers[monopoly_event.market.buy_failed]
    assert(type(handler) == "function", "buy_failed handler should be registered")
    handler(nil, nil, {
      reason = "charge_failed",
    })
  end)

  assert(#tips == 1, "fallback buy_failed should still emit tip")
  assert(tips[1].text == "黑市购买失败", "fallback tip should use default text")
  assert(number_utils.is_numeric(tips[1].duration), "fallback duration should be numeric")
  assert(tips[1].duration >= 1.0, "fallback tip duration should be at least 1 second")
end

return {
  name = "presentation_ui.event_handlers",
  tests = {
    {
      name = "market_buy_failed_shows_tip_for_at_least_one_second_and_pushes_popup",
      run = _test_market_buy_failed_shows_tip_for_at_least_one_second_and_pushes_popup,
    },
    {
      name = "market_buy_failed_without_popup_body_uses_fallback_tip",
      run = _test_market_buy_failed_without_popup_body_uses_fallback_tip,
    },
  },
}
