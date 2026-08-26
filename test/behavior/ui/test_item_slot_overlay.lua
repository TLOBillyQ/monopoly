-- 道具槽点击的遮挡门是**逐席位**的：模态画布本就只切给操作席（旁观者留在基础屏），
-- 所以对手的选择屏/黑市/弹窗没盖住我的屏幕，我的点击不该被连坐静默。
-- 只有真广播弹窗才盖住所有人。
local lu = require("luaunit")
local item_slot_overlay = require("src.ui.input.item_slot_overlay")

local function _assert_eq(actual, expected, msg)
  lu.assertEvalToTrue(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. " got " .. tostring(actual))
end

local function _state(ui)
  return { ui = ui }
end

TestItemSlotOverlay = {}

TestItemSlotOverlay["test_没有弹层时一律放行"] = function(self)
  _assert_eq(item_slot_overlay.blocks_click(_state({ current_action_role_id = 1 }), 1), false,
    "no overlay must never block")
end

TestItemSlotOverlay["test_对手的弹层不挡我的点击"] = function(self)
  local state = _state({ popup_active = true, current_action_role_id = 2 })
  _assert_eq(item_slot_overlay.blocks_click(state, 1), false,
    "another seat's overlay does not cover my screen")
end

TestItemSlotOverlay["test_自己的弹层挡住自己的点击"] = function(self)
  local state = _state({ popup_active = true, current_action_role_id = 1 })
  _assert_eq(item_slot_overlay.blocks_click(state, 1), true,
    "my own overlay covers my screen")
end

TestItemSlotOverlay["test_选择屏与黑市同口径:只挡操作席"] = function(self)
  for _, flag in ipairs({ "choice_active", "market_active" }) do
    local ui = { current_action_role_id = 2 }
    ui[flag] = true
    _assert_eq(item_slot_overlay.blocks_click(_state(ui), 1), false,
      flag .. " belonging to another seat must not block me")
    _assert_eq(item_slot_overlay.blocks_click(_state(ui), 2), true,
      flag .. " must block its own operator")
  end
end

TestItemSlotOverlay["test_广播弹窗盖住所有人"] = function(self)
  local state = _state({ popup_active = true, popup_broadcast = true, current_action_role_id = 2 })
  _assert_eq(item_slot_overlay.blocks_click(state, 1), true,
    "broadcast popups really do cover every screen")
end

TestItemSlotOverlay["test_归属或点击者解析不出时保守拦住"] = function(self)
  _assert_eq(item_slot_overlay.blocks_click(_state({ popup_active = true }), 1), true,
    "unresolvable operator must block conservatively")
  _assert_eq(item_slot_overlay.blocks_click(_state({ popup_active = true, current_action_role_id = 1 }), nil), true,
    "unknown clicker must block conservatively")
end


return TestItemSlotOverlay
