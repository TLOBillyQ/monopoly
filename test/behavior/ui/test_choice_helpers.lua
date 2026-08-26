-- choice_helpers.lua 直测:覆盖 resolve_canvas_for_screen 的 canvas_for 回落、
-- hide_choice_screens 的状态清理、set_option_node 的 touch_enabled 赋值。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _with_patches = support.with_patches

local choice_helpers = require("src.ui.coord.choice_helpers")
local canvas = require("src.ui.coord.canvas_coordinator")
local ui_controls = require("src.ui.render.support.ui_controls")
local runtime = require("src.ui.render.support.runtime_ui")
local runtime_state = require("src.ui.state.runtime")

TestChoiceHelpers = {}

-- resolve_canvas_for_screen:已知选择屏返回其固定画布
function TestChoiceHelpers:test_resolve_canvas_returns_registered_canvas()
  local result = choice_helpers.resolve_canvas_for_screen("target")
  lu.assertEquals(result, canvas.CANVAS_TARGET_CHOICE)
end

-- resolve_canvas_for_screen:未知 key 回落 CANVAS_BASE
function TestChoiceHelpers:test_resolve_canvas_falls_back_to_base()
  local result = choice_helpers.resolve_canvas_for_screen("unknown")
  lu.assertEquals(result, canvas.CANVAS_BASE)
end

-- hide_choice_screens: 清理 choice_active 和 active_choice_screen_key
function TestChoiceHelpers:test_hide_choice_screens_clears_state()
  local reset_calls = {}
  local ui = {
    choice_screens = {
      a = { root = "a_root" },
      b = { root = "b_root" },
    },
    choice_active = true,
    active_choice_screen_key = "some_key",
  }

  _with_patches({
    { target = ui_controls, key = "reset_choice_screen", value = function(_, screen)
      reset_calls[#reset_calls + 1] = screen.root
    end },
  }, function()
    choice_helpers.hide_choice_screens(ui)
  end)

  lu.assertEquals(#reset_calls, 2, "should reset both choice screens")
  lu.assertEquals(ui.choice_active, false, "choice_active must be false after hide")
  lu.assertEquals(ui.active_choice_screen_key, nil, "active_choice_screen_key must be nil after hide")
end

-- hide_choice_screens: choice_screens 为 nil 时不报错
function TestChoiceHelpers:test_hide_choice_screens_handles_nil_screens()
  local ui = {
    choice_active = true,
    active_choice_screen_key = "x",
  }
  _with_patches({
    { target = ui_controls, key = "reset_choice_screen", value = function() end },
  }, function()
    choice_helpers.hide_choice_screens(ui)
  end)
  lu.assertEquals(ui.choice_active, false)
  lu.assertIsNil(ui.active_choice_screen_key)
end

-- set_option_node: option 非 nil 时 touch_enabled 为 true
function TestChoiceHelpers:test_set_option_node_enables_touch_for_valid_option()
  local control_state = nil
  local set_button_calls = {}

  local ui = {
    set_button = function(_, node_name, label)
      set_button_calls[#set_button_calls + 1] = { node_name, label }
    end,
  }

  _with_patches({
    { target = ui_controls, key = "set_control_state", value = function(_, node_name, state)
      control_state = state
    end },
  }, function()
    choice_helpers.set_option_node(ui, "btn_1", { id = 1, label = "选项A" })
  end)

  lu.assertEquals(control_state.visible, true, "visible must be true when option exists")
  lu.assertEquals(control_state.touch_enabled, true, "touch_enabled must be true when option exists")
  lu.assertEquals(#set_button_calls, 1, "set_button must be called once")
end

-- set_option_node: option 为 nil 时 touch_enabled 为 false
function TestChoiceHelpers:test_set_option_node_disables_touch_for_nil_option()
  local control_state = nil
  local set_button_calls = {}

  local ui = {
    set_button = function(_, node_name, label)
      set_button_calls[#set_button_calls + 1] = { node_name, label }
    end,
  }

  _with_patches({
    { target = ui_controls, key = "set_control_state", value = function(_, node_name, state)
      control_state = state
    end },
  }, function()
    choice_helpers.set_option_node(ui, "btn_x", nil)
  end)

  lu.assertEquals(control_state.visible, false, "visible must be false when option is nil")
  lu.assertEquals(control_state.touch_enabled, false, "touch_enabled must be false when option is nil")
  lu.assertEquals(#set_button_calls, 0, "set_button must not be called for nil option")
end

-- switch_modal_canvas 覆盖（杀掉 L50 can_operate 判定四件套 + get_ui_model→nil 幸存者）：
-- 可操作角色切到目标画布，不可操作角色回落 CANVAS_BASE

local function _switch_model_for(role)
  return { current_player_id = "r1", item_slots_by_player_id = { r1 = {}, r2 = {} } }
end

local function _patch_switch_deps(with_calls)
  return {
    { target = runtime, key = "for_each_role_or_global",
      value = function(fn) fn("r1") end },
    { target = runtime, key = "resolve_role_id", value = function(role) return role end },
    { target = runtime_state, key = "get_ui_model", value = _switch_model_for },
    { target = runtime, key = "set_client_role", value = function() end },
    { target = canvas, key = "switch_for_role",
      value = function(_, target, role) with_calls[#with_calls + 1] = { target, role } end },
    { target = canvas, key = "switch", value = function() end },
  }
end

function TestChoiceHelpers:test_switch_modal_canvas_uses_target_canvas_when_role_can_operate()
  local calls = {}
  local ui = {}
  local state = { ui = ui }
  _with_patches(_patch_switch_deps(calls), function()
    choice_helpers.switch_modal_canvas(state, canvas.CANVAS_MARKET)
  end)
  lu.assertEquals(#calls, 1, "one role should switch canvas")
  lu.assertEquals(calls[1][1], canvas.CANVAS_MARKET,
    "can-operate role should switch to the target canvas")
  lu.assertEquals(calls[1][2], "r1", "role should be forwarded to switch_for_role")
end

function TestChoiceHelpers:test_switch_modal_canvas_falls_back_to_base_when_role_cannot_operate()
  local calls = {}
  local ui = {}
  local state = { ui = ui }
  _with_patches({
    { target = runtime, key = "for_each_role_or_global",
      value = function(fn) fn("r2") end },
    { target = runtime, key = "resolve_role_id", value = function(role) return role end },
    { target = runtime_state, key = "get_ui_model",
      value = function() return { current_player_id = "r1", item_slots_by_player_id = { r2 = {} } } end },
    { target = runtime, key = "set_client_role", value = function() end },
    { target = canvas, key = "switch_for_role",
      value = function(_, target, role) calls[#calls + 1] = { target, role } end },
    { target = canvas, key = "switch", value = function() end },
  }, function()
    choice_helpers.switch_modal_canvas(state, canvas.CANVAS_MARKET)
  end)
  lu.assertEquals(calls[1][1], canvas.CANVAS_BASE,
    "role that cannot operate should get the base canvas")
end

return TestChoiceHelpers
