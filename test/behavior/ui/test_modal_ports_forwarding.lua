-- src/ui/ports/modal.lua 的转发行为规约。该 port 是纯适配器：每个入口都
-- 必须真正抵达它的协调器。此前 manifest 只有 bootstrap 记录,require 级
-- 惰性突变（modal / secondary_confirm 换成 nil）全部幸存 —— 说明没有任何
-- 测试真的走过这些转发路径。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local modal_ports = require("src.ui.ports.modal")
local coord_modal = require("src.ui.coord.modal")
local popup_presenter = require("src.ui.coord.popup_presenter")
local secondary_confirm_screen = require("src.ui.screens.secondary_confirm")

TestModalPortsForwarding = {}

TestModalPortsForwarding["test_open/close_choice_modal 转发到 choice modal 协调器"] = function(self)
  local opened = nil
  local close_calls = 0
  local state = {}
  local choice = { id = 42 }
  local market = { stub = true }

  _with_patches({
    { target = coord_modal, key = "open_choice_modal", value = function(s, c, m)
      opened = { state = s, choice = c, market = m }
    end },
    { target = coord_modal, key = "close_choice_modal", value = function()
      close_calls = close_calls + 1
    end },
  }, function()
    local ports = modal_ports.build()
    ports.open_choice_modal(state, choice, market)
    ports.close_choice_modal(state)
  end)

  lu.assertEvalToTrue(opened ~= nil, "open_choice_modal must reach the modal coordinator")
  _assert_eq(opened.state, state, "open must forward the state handle untouched")
  _assert_eq(opened.choice, choice, "open must forward the choice untouched")
  _assert_eq(opened.market, market, "open must forward the market snapshot untouched")
  _assert_eq(close_calls, 1, "close_choice_modal must reach the modal coordinator exactly once")
end

TestModalPortsForwarding["test_open_pre_confirm_screen 五个实参原样抵达二次确认屏"] = function(self)
  local seen = nil
  local state = {}
  local choice = { id = 7 }

  _with_patches({
    { target = secondary_confirm_screen, key = "open_pre_confirm", value = function(s, c, option_id, title, body)
      seen = { state = s, choice = c, option_id = option_id, title = title, body = body }
    end },
  }, function()
    local ports = modal_ports.build()
    ports.open_pre_confirm_screen(state, choice, 33, "标题", "正文")
  end)

  lu.assertEvalToTrue(seen ~= nil, "open_pre_confirm_screen must reach the secondary confirm screen")
  _assert_eq(seen.state, state, "pre-confirm must forward the state handle")
  _assert_eq(seen.choice, choice, "pre-confirm must forward the choice")
  _assert_eq(seen.option_id, 33, "pre-confirm must forward the option id")
  _assert_eq(seen.title, "标题", "pre-confirm must forward the title")
  _assert_eq(seen.body, "正文", "pre-confirm must forward the body")
end

TestModalPortsForwarding["test_close_popup 转发到 popup presenter"] = function(self)
  local close_calls = 0
  local state = {}

  _with_patches({
    { target = popup_presenter, key = "close_popup", value = function()
      close_calls = close_calls + 1
    end },
  }, function()
    local ports = modal_ports.build()
    ports.close_popup(state)
  end)

  _assert_eq(close_calls, 1, "close_popup must reach the popup presenter exactly once")
end


return TestModalPortsForwarding
