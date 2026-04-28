local ui_runtime = require("src.ui.ctl.ui_runtime")

local _refresh_turn_label_for_runtime_role = ui_runtime._M_test._refresh_turn_label_for_runtime_role

local function _test_refresh_turn_label_visible_false_hides_label()
  local ui_calls = {}
  local ui = {
    set_visible = function(self, node, visible)
      ui_calls[#ui_calls + 1] = { method = "set_visible", node = node, visible = visible }
    end,
    set_label = function(self, node, text)
      ui_calls[#ui_calls + 1] = { method = "set_label", node = node, text = text }
    end,
  }

  local base_nodes = {
    countdown = "countdown_node",
    countdown_line = "countdown_line_node",
  }

  _refresh_turn_label_for_runtime_role(ui, base_nodes, "Turn: Player 1", false)

  assert(#ui_calls == 3, "expected 3 ui calls, got " .. #ui_calls)
  assert(ui_calls[1].method == "set_visible", "first call should be set_visible")
  assert(ui_calls[1].visible == false, "countdown visibility should be false")
  assert(ui_calls[2].method == "set_visible", "second call should be set_visible")
  assert(ui_calls[2].visible == false, "countdown_line visibility should be false")
  assert(ui_calls[3].method == "set_label", "third call should be set_label")
  assert(ui_calls[3].text == "Turn: Player 1", "label text should be set")
end

local function _test_refresh_turn_label_visible_nil_shows_label()
  local ui_calls = {}
  local ui = {
    set_visible = function(self, node, visible)
      ui_calls[#ui_calls + 1] = { method = "set_visible", node = node, visible = visible }
    end,
    set_label = function(self, node, text)
      ui_calls[#ui_calls + 1] = { method = "set_label", node = node, text = text }
    end,
  }

  local base_nodes = {
    countdown = "countdown_node",
    countdown_line = "countdown_line_node",
  }

  _refresh_turn_label_for_runtime_role(ui, base_nodes, "Turn: Player 2", nil)

  assert(#ui_calls == 3, "expected 3 ui calls, got " .. #ui_calls)
  assert(ui_calls[1].method == "set_visible", "first call should be set_visible")
  assert(ui_calls[1].visible == true, "countdown visibility should be true (nil defaults to true)")
  assert(ui_calls[2].method == "set_visible", "second call should be set_visible")
  assert(ui_calls[2].visible == true, "countdown_line visibility should be true")
  assert(ui_calls[3].method == "set_label", "third call should be set_label")
end

local function _test_refresh_turn_label_calls_set_label_with_expected_args()
  local ui_calls = {}
  local ui = {
    set_visible = function(self, node, visible)
      ui_calls[#ui_calls + 1] = { method = "set_visible", node = node, visible = visible }
    end,
    set_label = function(self, node, text)
      ui_calls[#ui_calls + 1] = { method = "set_label", node = node, text = text }
    end,
  }

  local base_nodes = {
    countdown = "countdown_node",
    countdown_line = "countdown_line_node",
  }

  local expected_text = "Time's running out!"
  _refresh_turn_label_for_runtime_role(ui, base_nodes, expected_text, true)

  assert(#ui_calls == 3, "expected 3 ui calls, got " .. #ui_calls)
  assert(ui_calls[3].method == "set_label", "third call should be set_label")
  assert(ui_calls[3].node == "countdown_node", "should set label on countdown node")
  assert(ui_calls[3].text == expected_text, "label text should match: expected '" .. expected_text .. "' got '" .. ui_calls[3].text .. "'")
end

return {
  name = "ui_runtime_refresh_turn_label_crap_coverage",
  tests = {
    { name = "_refresh_turn_label_for_runtime_role visible=false hides label", run = _test_refresh_turn_label_visible_false_hides_label },
    { name = "_refresh_turn_label_for_runtime_role visible=nil shows label with default behavior", run = _test_refresh_turn_label_visible_nil_shows_label },
    { name = "_refresh_turn_label_for_runtime_role calls set_label with expected args", run = _test_refresh_turn_label_calls_set_label_with_expected_args },
  },
}
