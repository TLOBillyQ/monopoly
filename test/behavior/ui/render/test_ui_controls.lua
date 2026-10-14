-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
-- Behavior specs for src/ui/render/support/ui_controls.lua.
-- ui_controls is the defensive seam between screen code and the host ui object:
-- it must tolerate a missing ui, a missing node name, and a ui that only
-- implements part of the control surface.


local ui_controls = require("src.ui.render.support.ui_controls")

local function _assert_eq(a, b, msg)
  luassert.is.equal(b, a, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- A ui stub that records every call. `omit` lists methods the stub should not
-- implement, so specs can drive a partially-capable host ui.
local function _stub_ui(omit)
  omit = omit or {}
  local ui = {
    visible = {},
    touch = {},
    labels = {},
    buttons = {},
    calls = 0,
  }
  if not omit.set_visible then
    ui.set_visible = function(self, name, value)
      self.visible[name] = value
      self.calls = self.calls + 1
    end
  end
  if not omit.set_touch_enabled then
    ui.set_touch_enabled = function(self, name, value)
      self.touch[name] = value
      self.calls = self.calls + 1
    end
  end
  if not omit.set_label then
    ui.set_label = function(self, name, text)
      self.labels[name] = text
      self.calls = self.calls + 1
    end
  end
  if not omit.set_button then
    ui.set_button = function(self, name, text)
      self.buttons[name] = text
      self.calls = self.calls + 1
    end
  end
  return ui
end

describe("TestUiControls", function()

  -- ui_controls.set_control_state
  it("test_applies_visible_and_touch_enabled_as_booleans", function()
    local ui = _stub_ui()
    ui_controls.set_control_state(ui, "node", { visible = true, touch_enabled = false })
    _assert_eq(ui.visible["node"], true, "visible applied")
    _assert_eq(ui.touch["node"], false, "touch_enabled applied")
  end)

  it("test_coerces_non_boolean_flags_to_false_rather_than_passing_them_through", function()
    local ui = _stub_ui()
    ui_controls.set_control_state(ui, "node", { visible = "yes", touch_enabled = 1 })
    _assert_eq(ui.visible["node"], false, "truthy non-true visible becomes false")
    _assert_eq(ui.touch["node"], false, "truthy non-true touch_enabled becomes false")
  end)

  it("test_leaves_a_control_untouched_when_the_flag_is_absent", function()
    local ui = _stub_ui()
    ui_controls.set_control_state(ui, "node", { visible = true })
    _assert_eq(ui.visible["node"], true, "given flag applied")
    _assert_eq(ui.touch["node"], nil, "absent flag must not reach the ui")
    _assert_eq(ui.calls, 1, "exactly one ui call for one flag")
  end)

  it("test_does_nothing_without_options_without_a_name_or_without_a_ui", function()
    local ui = _stub_ui()
    ui_controls.set_control_state(ui, "node", nil)
    ui_controls.set_control_state(ui, nil, { visible = true })
    ui_controls.set_control_state(nil, "node", { visible = true })
    _assert_eq(ui.calls, 0, "no ui call for empty options / missing name / missing ui")
  end)

  it("test_skips_flags_the_ui_cannot_apply", function()
    local ui = _stub_ui({ set_visible = true })
    ui_controls.set_control_state(ui, "node", { visible = true, touch_enabled = true })
    _assert_eq(ui.visible["node"], nil, "no set_visible method means no visibility change")
    _assert_eq(ui.touch["node"], true, "the supported flag is still applied")
  end)

  -- ui_controls.set_controls_state
  it("test_applies_the_same_options_to_every_name_in_the_list", function()
    local ui = _stub_ui()
    ui_controls.set_controls_state(ui, { "a", "b" }, { visible = false, touch_enabled = false })
    _assert_eq(ui.visible["a"], false, "first name hidden")
    _assert_eq(ui.visible["b"], false, "second name hidden")
    _assert_eq(ui.touch["b"], false, "second name touch disabled")
  end)

  it("test_ignores_a_non_table_name_list", function()
    local ui = _stub_ui()
    ui_controls.set_controls_state(ui, nil, { visible = true })
    ui_controls.set_controls_state(ui, "a", { visible = true })
    _assert_eq(ui.calls, 0, "non-table names produce no ui calls")
  end)

  -- ui_controls.set_slot_state
  it("test_applies_per_key_options_to_the_slots_node_names", function()
    local ui = _stub_ui()
    ui_controls.set_slot_state(ui, { icon = "slot_icon", label = "slot_label" }, {
      icon = { visible = true },
      label = { visible = false, touch_enabled = false },
    })
    _assert_eq(ui.visible["slot_icon"], true, "icon shown")
    _assert_eq(ui.visible["slot_label"], false, "label hidden")
    _assert_eq(ui.touch["slot_label"], false, "label touch disabled")
  end)

  it("test_ignores_keys_the_slot_does_not_define_and_a_non_table_slot", function()
    local ui = _stub_ui()
    ui_controls.set_slot_state(ui, { icon = "slot_icon" }, { missing = { visible = true } })
    ui_controls.set_slot_state(ui, nil, { icon = { visible = true } })
    _assert_eq(ui.calls, 0, "unknown slot keys and non-table slots produce no ui calls")
  end)

  it("test_applies_nothing_when_there_are_no_options_by_key", function()
    local ui = _stub_ui()
    ui_controls.set_slot_state(ui, { icon = "slot_icon" }, nil)
    _assert_eq(ui.calls, 0, "no options means no ui calls")
  end)

  do
    -- ui_controls.reset_choice_screen 共享夹具。
    local screen = {
      root = "root",
      title = "title",
      body = "body",
      confirm = "confirm",
      cancel = "cancel",
      option_buttons = { "opt1", "opt2" },
      slot_labels = { "slot_label1" },
      slot_projections = { "slot_proj1" },
      under_button = "under",
    }

    it("test_hides_the_root_and_clears_every_text_bearing_control", function()
      local ui = _stub_ui()
      ui_controls.reset_choice_screen(ui, screen)

      _assert_eq(ui.visible["root"], false, "root hidden")
      for _, name in ipairs({ "title", "body", "confirm", "cancel" }) do
        _assert_eq(ui.labels[name], "", name .. " label cleared")
        _assert_eq(ui.buttons[name], "", name .. " button text cleared")
      end
    end)

    it("test_hides_and_disables_confirm_cancel_options_slots_and_the_under_button", function()
      local ui = _stub_ui()
      ui_controls.reset_choice_screen(ui, screen)

      for _, name in ipairs({ "confirm", "cancel", "opt1", "opt2", "slot_label1", "slot_proj1", "under" }) do
        _assert_eq(ui.visible[name], false, name .. " hidden")
        _assert_eq(ui.touch[name], false, name .. " touch disabled")
      end
    end)

    it("test_clears_text_through_whichever_text_method_the_ui_implements", function()
      local ui = _stub_ui({ set_label = true })
      ui_controls.reset_choice_screen(ui, screen)
      _assert_eq(ui.buttons["title"], "", "button text still cleared without set_label")
      _assert_eq(ui.labels["title"], nil, "no set_label method means no label call")
    end)

    it("test_ignores_a_non_table_screen", function()
      local ui = _stub_ui()
      ui_controls.reset_choice_screen(ui, nil)
      _assert_eq(ui.calls, 0, "non-table screen produces no ui calls")
    end)

    it("test_skips_text_clearing_for_controls_the_screen_does_not_name", function()
      local ui = _stub_ui()
      ui_controls.reset_choice_screen(ui, { root = "root" })
      _assert_eq(ui.visible["root"], false, "root still hidden")
      _assert_eq(ui.calls, 1, "a screen with only a root touches only the root")
    end)
  end


end)
