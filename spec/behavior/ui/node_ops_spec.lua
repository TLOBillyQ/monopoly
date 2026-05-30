local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches

local runtime = require("src.ui.render.runtime_ui")
local node_ops = require("src.ui.render.node_ops")
local base_contract = require("src.ui.schema.base_contract")
local debug_nodes = require("src.ui.schema.debug")

local function _ok(val, msg)
  assert(val, msg or "expected truthy")
end

describe("node_ops", function()
  describe("set_text", function()
    it("sets text on queried node", function()
      local node = { text = "" }
      _with_patches({
        { target = runtime, key = "query_nodes", value = function() return { node } end },
        { target = runtime, key = "get_client_role", value = function() return "role1" end },
      }, function()
        node_ops.set_text(nil, "test_label", "hello")
      end)
      _assert_eq(node.text, "hello", "text should be set")
    end)

    it("defaults nil text to empty string", function()
      local node = { text = "old" }
      _with_patches({
        { target = runtime, key = "query_nodes", value = function() return { node } end },
        { target = runtime, key = "get_client_role", value = function() return "role1" end },
      }, function()
        node_ops.set_text(nil, "test_label", nil)
      end)
      _assert_eq(node.text, "", "nil text should default to empty")
    end)
  end)

  describe("set_visible", function()
    it("sets visible true", function()
      local node = { visible = false }
      _with_patches({
        { target = runtime, key = "query_nodes", value = function() return { node } end },
        { target = runtime, key = "get_client_role", value = function() return "role1" end },
        { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
      }, function()
        node_ops.set_visible(nil, "test_node", true)
      end)
      _ok(node.visible == true, "visible should be true")
    end)

    it("sets visible false", function()
      local node = { visible = true }
      _with_patches({
        { target = runtime, key = "query_nodes", value = function() return { node } end },
        { target = runtime, key = "get_client_role", value = function() return "role1" end },
        { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
      }, function()
        node_ops.set_visible(nil, "test_node", false)
      end)
      _ok(node.visible == false, "visible should be false")
    end)

    it("coerces truthy non-true to false", function()
      local node = { visible = true }
      _with_patches({
        { target = runtime, key = "query_nodes", value = function() return { node } end },
        { target = runtime, key = "get_client_role", value = function() return "role1" end },
        { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
      }, function()
        node_ops.set_visible(nil, "test_node", 1)
      end)
      _ok(node.visible == false, "non-true truthy should become false (visible == true check)")
    end)

  end)

  describe("set_touch_enabled", function()
    it("sets disabled false when enabled true", function()
      local node = { disabled = true }
      _with_patches({
        { target = runtime, key = "query_nodes", value = function() return { node } end },
        { target = runtime, key = "get_client_role", value = function() return "role1" end },
        { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
      }, function()
        node_ops.set_touch_enabled(nil, "test_button", true)
      end)
      _ok(node.disabled == false, "disabled should be false when enabled")
    end)

    it("sets disabled true when enabled false", function()
      local node = { disabled = false }
      _with_patches({
        { target = runtime, key = "query_nodes", value = function() return { node } end },
        { target = runtime, key = "get_client_role", value = function() return "role1" end },
        { target = runtime, key = "resolve_role_id", value = function() return "role:1" end },
      }, function()
        node_ops.set_touch_enabled(nil, "test_button", false)
      end)
      _ok(node.disabled == true, "disabled should be true when not enabled")
    end)

  end)

  describe("set_item_slot_image", function()
    it("sets texture on slot nodes with active role", function()
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
    end)

    it("iterates all roles when no active role", function()
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
    end)

    it("rejects nil slot name", function()
      local ok = pcall(node_ops.set_item_slot_image, nil, "ICON")
      _ok(not ok, "should reject nil slot name")
    end)

    it("rejects nil image key", function()
      local ok = pcall(node_ops.set_item_slot_image, "slot_1", nil)
      _ok(not ok, "should reject nil image key")
    end)
  end)

  describe("sync_target_choice_buttons", function()
    it("hides confirm and cancel buttons", function()
      local calls = {}
      local ui = {
        choice_screens = {
          target = {
            confirm = "confirm_btn",
            cancel = "cancel_btn",
          },
        },
        set_button = function(_, name)
          calls[#calls + 1] = { op = "set_button", name = name }
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
      for _, call in ipairs(calls) do
        if call.name == "confirm_btn" and call.op == "set_visible" and call.visible == false then
          confirm_hidden = true
        end
        if call.name == "cancel_btn" and call.op == "set_visible" and call.visible == false then
          cancel_hidden = true
        end
      end
      _ok(confirm_hidden, "confirm should be hidden")
      _ok(cancel_hidden, "cancel should be hidden")
    end)

    it("does nothing when ui is nil", function()
      local ok = pcall(node_ops.sync_target_choice_buttons, { ui = nil })
      _ok(ok, "should not error with nil ui")
    end)

    it("does nothing when target screen is nil", function()
      local ok = pcall(node_ops.sync_target_choice_buttons, { ui = { choice_screens = {} } })
      _ok(ok, "should not error with nil target screen")
    end)

    it("does nothing when button name is nil", function()
      local calls = {}
      local ui = {
        choice_screens = {
          target = {
            confirm = nil,
            cancel = nil,
          },
        },
        set_button = function(_, name)
          calls[#calls + 1] = { op = "set_button", name = name }
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
    end)
  end)

  describe("build_choice_screens", function()
    it("returns screens with player, target, remote, secondary_confirm keys", function()
      local screens = node_ops.build_choice_screens()
      _ok(screens.player ~= nil, "should have player screen")
      _ok(screens.target ~= nil, "should have target screen")
      _ok(screens.remote ~= nil, "should have remote screen")
      _ok(screens.secondary_confirm ~= nil, "should have secondary_confirm screen")
    end)

    it("sets correct key for each screen", function()
      local screens = node_ops.build_choice_screens()
      _assert_eq(screens.player.key, "player", "player key")
      _assert_eq(screens.target.key, "target", "target key")
      _assert_eq(screens.remote.key, "remote", "remote key")
      _assert_eq(screens.secondary_confirm.key, "secondary_confirm", "secondary_confirm key")
    end)

    it("target screen has confirm and cancel nodes", function()
      local screens = node_ops.build_choice_screens()
      _ok(screens.target.confirm ~= nil, "target should have confirm")
      _ok(screens.target.cancel ~= nil, "target should have cancel")
    end)

    it("secondary_confirm screen has confirm and cancel nodes", function()
      local screens = node_ops.build_choice_screens()
      _ok(screens.secondary_confirm.confirm ~= nil, "secondary_confirm should have confirm")
      _ok(screens.secondary_confirm.cancel ~= nil, "secondary_confirm should have cancel")
    end)

    it("all screens have root and title nodes", function()
      local screens = node_ops.build_choice_screens()
      for key, screen in pairs(screens) do
        _ok(screen.root ~= nil, key .. " should have root")
        _ok(screen.title ~= nil, key .. " should have title")
      end
    end)

    it("target screen has body, option_buttons, slot_labels, slot_projections", function()
      local screens = node_ops.build_choice_screens()
      _ok(screens.target.body ~= nil, "target should have body")
      _ok(screens.target.option_buttons ~= nil, "target should have option_buttons")
      _ok(screens.target.slot_labels ~= nil, "target should have slot_labels")
      _ok(screens.target.slot_projections ~= nil, "target should have slot_projections")
    end)
  end)

  describe("set_event_log", function()
    it("sets text on action log label", function()
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
    end)
  end)

  describe("set_event_log_visible", function()
    it("sets debug_visible on ui when ui provided", function()
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
    end)

    it("does not set debug_visible when ui is nil", function()
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
    end)

    it("hides canvas when visible is false", function()
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
    end)
  end)

  describe("mutate_node", function()
    it("calls mutator on single node when active role", function()
      local node = { text = "" }
      _with_patches({
        { target = runtime, key = "query_nodes", value = function() return { node } end },
        { target = runtime, key = "get_client_role", value = function() return "role1" end },
      }, function()
        node_ops.set_text(nil, "test", "x")
      end)
      _assert_eq(node.text, "x", "text should be set via single path")
    end)

    it("calls for_each_role_or_global when no active role", function()
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
    end)

    it("rejects nil name", function()
      local ok = pcall(node_ops.set_text, nil, nil, "x")
      _ok(not ok, "should reject nil name")
    end)
  end)
end)
