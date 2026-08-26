local lu = require("luaunit")
local support = require("test.support.shared_support")
local panel_interrupt = require("src.ui.state.panel_interrupt")
local panel_controls = require("src.ui.render.widgets.panel_controls")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _with_interrupt_patch(overrides, fn)
  local saved = {}
  for k, v in pairs(overrides) do
    saved[k] = panel_interrupt[k]
    panel_interrupt[k] = v
  end
  local ok, err = pcall(fn)
  for k, v in pairs(saved) do
    panel_interrupt[k] = v
  end
  if not ok then
    error(err, 2)
  end
end

TestPanelControls = {}

function TestPanelControls:tearDown()
  support.restore_runtime_services()
end

-- ===== is_base_non_player_visible =====

function TestPanelControls:test_is_base_non_player_visible_input_blocked_returns_false()
  local ui = { input_blocked = true }
  local ctx = { can_operate = true }
  _assert_eq(panel_controls.is_base_non_player_visible(ui, ctx), false,
    "input blocked should hide base non-player controls")
end

function TestPanelControls:test_is_base_non_player_visible_settlement_active_returns_false()
  _with_interrupt_patch({ settlement_type = function() return "some_settlement" end }, function()
    local ui = { input_blocked = false }
    local ctx = { can_operate = true }
    _assert_eq(panel_controls.is_base_non_player_visible(ui, ctx), false,
      "active settlement should hide base non-player controls")
  end)
end

function TestPanelControls:test_is_base_non_player_visible_no_interrupt_can_operate_returns_true()
  _with_interrupt_patch({ settlement_type = function() return nil end }, function()
    local ui = { input_blocked = false }
    local ctx = { can_operate = true }
    _assert_eq(panel_controls.is_base_non_player_visible(ui, ctx), true,
      "no interrupt with can_operate should show controls")
  end)
end

function TestPanelControls:test_is_base_non_player_visible_cannot_operate_returns_false()
  _with_interrupt_patch({ settlement_type = function() return nil end }, function()
    local ui = { input_blocked = false }
    local ctx = { can_operate = false }
    _assert_eq(panel_controls.is_base_non_player_visible(ui, ctx), false,
      "cannot operate should hide controls")
  end)
end

-- ===== is_base_cancel_allowed =====

function TestPanelControls:test_is_base_cancel_allowed_input_blocked_returns_false()
  local ui = { input_blocked = true }
  local ctx = { can_operate = true }
  _assert_eq(panel_controls.is_base_cancel_allowed(ui, ctx), false,
    "input blocked should disallow cancel")
end

function TestPanelControls:test_is_base_cancel_allowed_choice_type_does_not_block_cancel()
  _with_interrupt_patch({
    settlement_type_excluding_choice = function() return nil end,
  }, function()
    local ui = { input_blocked = false }
    local ctx = { can_operate = true }
    _assert_eq(panel_controls.is_base_cancel_allowed(ui, ctx), true,
      "no interrupt should allow cancel")
  end)
end

function TestPanelControls:test_is_base_cancel_allowed_non_choice_settlement_blocks_cancel()
  _with_interrupt_patch({
    settlement_type_excluding_choice = function() return "black_market" end,
  }, function()
    local ui = { input_blocked = false }
    local ctx = { can_operate = true }
    _assert_eq(panel_controls.is_base_cancel_allowed(ui, ctx), false,
      "non-choice settlement should block cancel")
  end)
end

function TestPanelControls:test_is_base_cancel_allowed_cannot_operate_returns_false()
  _with_interrupt_patch({
    settlement_type_excluding_choice = function() return nil end,
  }, function()
    local ui = { input_blocked = false }
    local ctx = { can_operate = false }
    _assert_eq(panel_controls.is_base_cancel_allowed(ui, ctx), false,
      "cannot operate should disallow cancel")
  end)
end

-- ===== is_slot_touch_allowed =====

function TestPanelControls:test_is_slot_touch_allowed_no_overlay_returns_true()
  _with_interrupt_patch({ is_overlay_visible = function() return false end }, function()
    _assert_eq(panel_controls.is_slot_touch_allowed({}), true,
      "no overlay should allow slot touch")
  end)
end

function TestPanelControls:test_is_slot_touch_allowed_with_overlay_returns_false()
  _with_interrupt_patch({ is_overlay_visible = function() return true end }, function()
    _assert_eq(panel_controls.is_slot_touch_allowed({}), false,
      "overlay visible should deny slot touch")
  end)
end

-- ===== apply_auto_effect (无桩断言 = Eggy 宿主透传) =====

function TestPanelControls:test_apply_auto_effect_calls_host_visibility_with_correct_params()
  local set_visible_calls = {}
  local set_touch_calls = {}
  local ui = {
    set_visible = function(_, name, visible)
      set_visible_calls[#set_visible_calls + 1] = { name = name, visible = visible }
    end,
    set_touch_enabled = function(_, name, enabled)
      set_touch_calls[#set_touch_calls + 1] = { name = name, enabled = enabled }
    end,
  }
  local ui_model = { delegated_by_player = {} }
  local ctx = { is_player_role = true, role_id = 1 }

  panel_controls.apply_auto_effect(ui, ui_model, ctx)

  lu.assertEvalToTrue(#set_visible_calls >= 1, "set_visible should be called at least once")
  lu.assertEvalToTrue(#set_touch_calls >= 1, "set_touch_enabled should be called at least once")
  _assert_eq(set_touch_calls[1].enabled, false, "auto_effect touch should be disabled")
end

-- ===== resolve_skin_entry_visible =====

function TestPanelControls:test_resolve_skin_entry_visible_nil_current_player_returns_false()
  local ui_model = { current_player_id = nil }
  local ctx = { can_operate = true }
  _assert_eq(panel_controls.resolve_skin_entry_visible(ui_model, ctx), false,
    "nil current player should hide skin entry")
end

function TestPanelControls:test_resolve_skin_entry_visible_can_operate_returns_false()
  local ui_model = { current_player_id = 1 }
  local ctx = { can_operate = true }
  _assert_eq(panel_controls.resolve_skin_entry_visible(ui_model, ctx), false,
    "can operate should NOT show skin entry (only shown when cannot operate)")
end

function TestPanelControls:test_resolve_skin_entry_visible_cannot_operate_returns_true()
  local ui_model = { current_player_id = 1 }
  local ctx = { can_operate = false }
  _assert_eq(panel_controls.resolve_skin_entry_visible(ui_model, ctx), true,
    "cannot operate should show skin entry")
end

return TestPanelControls
