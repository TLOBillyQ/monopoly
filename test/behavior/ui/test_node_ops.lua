local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local luax = require("test.support.luax")

local runtime = require("src.ui.render.support.runtime_ui")
local node_ops = require("src.ui.render.support.node_ops")
local base_contract = require("src.ui.schema.base_contract")
local debug_nodes = require("src.ui.schema.debug")

local function _ok(val, msg)
  assert(val, msg or "expected truthy")
end

TestNodeOps = {}

function TestNodeOps:test_sets_text_on_queried_node()
  local node = { text = "" }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
  }, function()
    node_ops.set_text(nil, "test_label", "hello")
  end)
  _assert_eq(node.text, "hello", "text should be set")
end

function TestNodeOps:test_defaults_nil_text_to_empty_string()
  local node = { text = "old" }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
  }, function()
    node_ops.set_text(nil, "test_label", nil)
  end)
  _assert_eq(node.text, "", "nil text should default to empty")
end

function TestNodeOps:test_sets_visible_true()
  local node = { visible = false }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
    { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
  }, function()
    node_ops.set_visible(nil, "test_node", true)
  end)
  _ok(node.visible == true, "visible should be true")
end

function TestNodeOps:test_sets_visible_false()
  local node = { visible = true }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
    { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
  }, function()
    node_ops.set_visible(nil, "test_node", false)
  end)
  _ok(node.visible == false, "visible should be false")
end

function TestNodeOps:test_coerces_truthy_non_true_to_false()
  local node = { visible = true }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
    { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
  }, function()
    node_ops.set_visible(nil, "test_node", 1)
  end)
  _ok(node.visible == false, "non-true truthy should become false (visible == true check)")
end

function TestNodeOps:test_sets_disabled_false_when_enabled_true()
  local node = { disabled = true }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
    { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
  }, function()
    node_ops.set_touch_enabled(nil, "test_button", true)
  end)
  _ok(node.disabled == false, "disabled should be false when enabled")
end

function TestNodeOps:test_sets_disabled_true_when_enabled_false()
  local node = { disabled = false }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
    { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
  }, function()
    node_ops.set_touch_enabled(nil, "test_button", false)
  end)
  _ok(node.disabled == true, "disabled should be true when not enabled")
end

function TestNodeOps:test_sets_texture_on_slot_nodes_with_active_role()
  local node = {}
  local texture_calls = {}
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
    { target = runtime, key = "set_node_texture_keep_size", value = function(n, key)
      texture_calls[#texture_calls + 1] = { node = n, key = key }
    end },
  }, function()
    node_ops.set_item_slot_image("slot_1", "ICON_2001")
  end)

  _assert_eq(#texture_calls, 1, "should set one texture")
  _assert_eq(texture_calls[1].key, "ICON_2001", "should use correct image key")
end

function TestNodeOps:test_iterates_all_roles_when_no_active_role()
  local node = {}
  local texture_calls = {}
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return nil end },
    { target = runtime, key = "for_each_role_or_global", value = function(fn)
      for _ = 1, 3 do fn() end
    end },
    { target = runtime, key = "set_node_texture_keep_size", value = function(n, key)
      texture_calls[#texture_calls + 1] = { node = n, key = key }
    end },
  }, function()
    node_ops.set_item_slot_image("slot_1", "ICON_2002")
  end)

  _assert_eq(#texture_calls, 3, "should set texture for each role iteration")
end

function TestNodeOps:test_rejects_nil_slot_name()
  local ok = pcall(node_ops.set_item_slot_image, nil, "ICON")
  _ok(not ok, "should reject nil slot name")
  -- 消息钉:变异把 "missing slot name" -> nil 后无消息,has_error 必须露馅。
  luax.has_error(function()
    node_ops.set_item_slot_image(nil, "ICON")
  end, "missing slot name")
end

function TestNodeOps:test_rejects_nil_image_key()
  local ok = pcall(node_ops.set_item_slot_image, "slot_1", nil)
  _ok(not ok, "should reject nil image key")
end

function TestNodeOps:test_hides_confirm_and_cancel_buttons()
  local calls = {}
  local ui = {
    choice_screens = {
      target = {
        confirm = "confirm_btn",
        cancel = "cancel_btn",
      },
    },
    set_button = function(_, name, text)
      calls[#calls + 1] = { op = "set_button", name = name, text = text }
    end,
    set_visible = function(_, name, visible)
      calls[#calls + 1] = { op = "set_visible", name = name, visible = visible }
    end,
    set_touch_enabled = function(_, name, enabled)
      calls[#calls + 1] = { op = "set_touch_enabled", name = name, enabled = enabled }
    end,
  }

  node_ops.sync_target_choice_buttons({ ui = ui })

  local confirm_hidden = false
  local cancel_hidden = false
  local confirm_cleared = false
  local confirm_disabled = false
  for _, call in ipairs(calls) do
    if call.name == "confirm_btn" and call.op == "set_visible" and call.visible == false then
      confirm_hidden = true
    end
    if call.name == "cancel_btn" and call.op == "set_visible" and call.visible == false then
      cancel_hidden = true
    end
    if call.name == "confirm_btn" and call.op == "set_button" and call.text == "" then
      confirm_cleared = true
    end
    if call.name == "confirm_btn" and call.op == "set_touch_enabled" and call.enabled == false then
      confirm_disabled = true
    end
  end
  _ok(confirm_hidden, "confirm should be hidden")
  _ok(cancel_hidden, "cancel should be hidden")
  _ok(confirm_cleared, "confirm text should be cleared to empty")
  _ok(confirm_disabled, "confirm should be touch-disabled")
end

function TestNodeOps:test_does_nothing_when_ui_is_nil()
  local ok = pcall(node_ops.sync_target_choice_buttons, { ui = nil })
  _ok(ok, "should not error with nil ui")
end

function TestNodeOps:test_does_nothing_when_target_screen_is_nil()
  local ok = pcall(node_ops.sync_target_choice_buttons, { ui = { choice_screens = {} } })
  _ok(ok, "should not error with nil target screen")
end

function TestNodeOps:test_does_nothing_when_button_name_is_nil()
  local calls = {}
  local ui = {
    choice_screens = {
      target = {
        confirm = nil,
        cancel = nil,
      },
    },
    set_button = function(_, name, text)
      calls[#calls + 1] = { op = "set_button", name = name, text = text }
    end,
    set_visible = function(_, name)
      calls[#calls + 1] = { op = "set_visible", name = name }
    end,
    set_touch_enabled = function(_, name)
      calls[#calls + 1] = { op = "set_touch_enabled", name = name }
    end,
  }

  node_ops.sync_target_choice_buttons({ ui = ui })
  _assert_eq(#calls, 0, "should not call any methods when button names are nil")
end

function TestNodeOps:test_returns_screens_with_player_target_remote_secondary_confirm_keys()
  local screens = require("src.ui.screens_registry").build_choice_screens()
  _ok(screens.player ~= nil, "should have player screen")
  _ok(screens.target ~= nil, "should have target screen")
  _ok(screens.remote ~= nil, "should have remote screen")
  _ok(screens.secondary_confirm ~= nil, "should have secondary_confirm screen")
end

function TestNodeOps:test_sets_correct_key_for_each_screen()
  local screens = require("src.ui.screens_registry").build_choice_screens()
  _assert_eq(screens.player.key, "player", "player key")
  _assert_eq(screens.target.key, "target", "target key")
  _assert_eq(screens.remote.key, "remote", "remote key")
  _assert_eq(screens.secondary_confirm.key, "secondary_confirm", "secondary_confirm key")
end

function TestNodeOps:test_target_screen_has_confirm_and_cancel_nodes()
  local screens = require("src.ui.screens_registry").build_choice_screens()
  _ok(screens.target.confirm ~= nil, "target should have confirm")
  _ok(screens.target.cancel ~= nil, "target should have cancel")
end

function TestNodeOps:test_secondary_confirm_screen_has_confirm_and_cancel_nodes()
  local screens = require("src.ui.screens_registry").build_choice_screens()
  _ok(screens.secondary_confirm.confirm ~= nil, "secondary_confirm should have confirm")
  _ok(screens.secondary_confirm.cancel ~= nil, "secondary_confirm should have cancel")
end

function TestNodeOps:test_all_screens_have_root_and_title_nodes()
  local screens = require("src.ui.screens_registry").build_choice_screens()
  for key, screen in pairs(screens) do
    _ok(screen.root ~= nil, key .. " should have root")
    _ok(screen.title ~= nil, key .. " should have title")
  end
end

function TestNodeOps:test_target_screen_has_body_option_buttons_slot_labels_slot_projections()
  local screens = require("src.ui.screens_registry").build_choice_screens()
  _ok(screens.target.body ~= nil, "target should have body")
  _ok(screens.target.option_buttons ~= nil, "target should have option_buttons")
  _ok(screens.target.slot_labels ~= nil, "target should have slot_labels")
  _ok(screens.target.slot_projections ~= nil, "target should have slot_projections")
end

function TestNodeOps:test_sets_text_on_action_log_label()
  local node = { text = "" }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function(name)
      if name == base_contract.action_log.label then return { node } end
      return {}
    end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
  }, function()
    node_ops.set_event_log(nil, "test log message")
  end)
  _assert_eq(node.text, "test log message", "should set event log text")
end

function TestNodeOps:test_sets_debug_visible_on_ui_when_ui_provided()
  local node = { visible = false }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function(name)
      if name == debug_nodes.canvas then return { node } end
      return {}
    end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
    { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
  }, function()
    local ui = {}
    node_ops.set_event_log_visible(ui, true)
    _ok(ui.debug_visible == true, "ui.debug_visible should be true")
    _ok(node.visible == true, "canvas should be visible")
  end)
end

function TestNodeOps:test_does_not_set_debug_visible_when_ui_is_nil()
  local node = { visible = false }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function(name)
      if name == debug_nodes.canvas then return { node } end
      return {}
    end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
    { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
  }, function()
    node_ops.set_event_log_visible(nil, true)
    _ok(node.visible == true, "canvas should still be visible")
  end)
end

function TestNodeOps:test_hides_canvas_when_visible_is_false()
  local node = { visible = true }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function(name)
      if name == debug_nodes.canvas then return { node } end
      return {}
    end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
    { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
  }, function()
    node_ops.set_event_log_visible(nil, false)
    _ok(node.visible == false, "canvas should be hidden")
  end)
end

function TestNodeOps:test_calls_mutator_on_single_node_when_active_role()
  local node = { text = "" }
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return "role1" end },
  }, function()
    node_ops.set_text(nil, "test", "x")
  end)
  _assert_eq(node.text, "x", "text should be set via single path")
end

function TestNodeOps:test_calls_for_each_role_or_global_when_no_active_role()
  local node = { text = "" }
  local role_calls = 0
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return nil end },
    { target = runtime, key = "for_each_role_or_global", value = function(fn)
      role_calls = role_calls + 1
      fn()
    end },
  }, function()
    node_ops.set_text(nil, "test", "x")
  end)
  _assert_eq(role_calls, 1, "should call for_each_role_or_global once")
end

function TestNodeOps:test_rejects_nil_name()
  local ok = pcall(node_ops.set_text, nil, nil, "x")
  _ok(not ok, "should reject nil name")
  -- 消息钉:变异把 "missing ui node name" -> nil 后无消息,has_error 必须露馅。
  luax.has_error(function()
    node_ops.set_text(nil, nil, "x")
  end, "missing ui node name")
end


return TestNodeOps
