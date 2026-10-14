-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
local action_gate = require("src.turn.policies.action_gate")

local function _gate(overrides)
  return action_gate.resolve_gate_state(overrides or {})
end

local function _blocked(gate_state, action)
  return action_gate.should_block_action(gate_state, action)
end

describe("TestActionGate", function()

it("test_nil_action_type_never_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, nil) == false, "nil action is always permitted")
end)

it("test_popup_confirm_never_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, "popup_confirm") == false, "popup_confirm always permitted")
end)

it("test_auto_button_never_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, { type = "ui_button", id = "auto" }) == false, "auto button always permitted")
end)

-- #162「道具槽全时段可点、点了必有反馈」的承重墙：item_slot_click 自身不推进
-- 状态（要么被裁定拒绝只发提示，要么转成 choice_select 再过一次本闸），所以
-- 输入锁期间必须放行——拦掉它，移动动画等阶段位里点卡就退回零反馈。
it("test_item_slot_click_never_blocked", function()
  for _, gate_flags in ipairs({
    { input_blocked = true },
    { input_blocked = true, choice_active = true, popup_active = true, market_active = true },
  }) do
    local gate = _gate(gate_flags)
    luassert.truthy(_blocked(gate, { type = "item_slot_click", slot_index = 1 }) == false,
      "item slot clicks must always reach the verdict")
  end
end)

it("test_next_button_blocked_when_choice_active", function()
  local gate = _gate({ input_blocked = false, choice_active = true })
  luassert.truthy(_blocked(gate, { type = "ui_button", id = "next" }) == true, "next blocked during choice")
end)

it("test_next_button_blocked_when_market_active", function()
  local gate = _gate({ input_blocked = false, market_active = true })
  luassert.truthy(_blocked(gate, { type = "ui_button", id = "next" }) == true, "next blocked during market")
end)

it("test_next_button_blocked_when_popup_active", function()
  local gate = _gate({ input_blocked = false, popup_active = true })
  luassert.truthy(_blocked(gate, { type = "ui_button", id = "next" }) == true, "next blocked during popup")
end)

it("test_next_button_blocked_when_detained_active", function()
  local gate = _gate({ input_blocked = false, detained_wait_active = true })
  luassert.truthy(_blocked(gate, { type = "ui_button", id = "next" }) == true, "next blocked during detained wait")
end)

it("test_next_button_blocked_via_input_blocked_types_when_no_modal", function()
  local gate = _gate({ input_blocked = true, choice_active = false, market_active = false, popup_active = false, detained_wait_active = false })
  luassert.truthy(_blocked(gate, { type = "ui_button", id = "next" }) == true, "next falls through to input_blocked_types when no modal")
end)

it("test_next_button_not_blocked_when_input_not_blocked_and_no_modal", function()
  local gate = _gate({ input_blocked = false })
  luassert.truthy(_blocked(gate, { type = "ui_button", id = "next" }) == false, "next not blocked when input not blocked and no modal")
end)

it("test_ui_button_blocked_when_input_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, { type = "ui_button", id = "other" }) == true, "ui_button blocked when input_blocked")
end)

it("test_choice_pick_blocked_when_input_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, "choice_pick") == true, "choice_pick blocked when input_blocked")
end)

it("test_market_confirm_blocked_when_input_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, "market_confirm") == true, "market_confirm blocked when input_blocked")
end)

it("test_market_select_blocked_when_input_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, "market_select") == true, "market_select blocked when input_blocked")
end)

it("test_market_page_prev_blocked_when_input_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, "market_page_prev") == true, "market_page_prev blocked when input_blocked")
end)

it("test_market_page_next_blocked_when_input_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, "market_page_next") == true, "market_page_next blocked when input_blocked")
end)

it("test_market_tab_select_blocked_when_input_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, "market_tab_select") == true, "market_tab_select blocked when input_blocked")
end)

it("test_choice_cancel_blocked_when_input_blocked", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, "choice_cancel") == true, "choice_cancel blocked when input_blocked")
end)

it("test_not_blocked_when_input_not_blocked", function()
  local gate = _gate({ input_blocked = false })
  luassert.truthy(_blocked(gate, "choice_pick") == false, "choice_pick not blocked when input not blocked")
end)

it("test_string_action_same_as_table_action", function()
  local gate = _gate({ input_blocked = true })
  luassert.truthy(_blocked(gate, "ui_button") == true, "string ui_button also blocked")
end)

it("test_resolve_gate_state_from_boolean_flag", function()
  local gate = action_gate.resolve_gate_state(true)
  luassert.truthy(gate.input_blocked == true, "true flag sets input_blocked")
  luassert.truthy(gate.choice_active == false, "choice_active defaults false")
  local gate_false = action_gate.resolve_gate_state(false)
  luassert.truthy(gate_false.input_blocked == false, "false flag clears input_blocked")
end)
end)
