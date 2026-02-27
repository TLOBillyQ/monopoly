local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local bindings = require("src.presentation.interaction.UIEventBindings")
local ui_nodes = require("src.presentation.shared.UINodes")
local logger = require("src.core.Logger")
local runtime = require("src.presentation.api.UIRuntimePort")

local function _build_crash_node()
  local node = {}
  return setmetatable(node, {
    __newindex = function(_, key, _)
      if key == "disabled" then
        error("set_node_touch_enabled 节点类型不正确")
      end
      rawset(node, key, nil)
    end,
  })
end

local function _test_enable_action_log_toggle_touch_fallback_never_crash_on_bad_cached_nodes()
  logger.clear()
  local cache = {
    [ui_nodes.always_show.action_log_button] = { _build_crash_node() },
  }
  local manager = { client_role = { any = true } }

  local ok = false
  _with_patches({
    { key = "UIManager", value = manager },
    { target = runtime, key = "set_client_role", value = function(role)
      manager.client_role = role
    end },
  }, function()
    ok = pcall(bindings.enable_action_log_toggle_touch, cache, nil)
  end)

  assert(ok, "enable_action_log_toggle_touch should not crash on bad cached nodes")
  _assert_eq(manager.client_role, nil, "fallback should restore client role to nil")
end

local function _test_enable_action_log_toggle_touch_prefers_named_ui_touch_path()
  logger.clear()
  local calls = {}
  local ui = {
    set_touch_enabled = function(_, name, enabled)
      calls[#calls + 1] = { name = name, enabled = enabled }
    end,
  }

  _with_patches({
    { target = runtime, key = "query_nodes", value = function(name)
      error("query_nodes should not be called for ui path: " .. tostring(name))
    end },
  }, function()
    bindings.enable_action_log_toggle_touch({}, ui)
  end)

  _assert_eq(#calls, 1, "ui path should touch one action-log toggle node")
  _assert_eq(calls[1].name, ui_nodes.always_show.action_log_button, "touch should target action-log button")
  _assert_eq(calls[1].enabled, true, "toggle button should be enabled")
end

return {
  name = "presentation_ui.event_bindings",
  tests = {
    {
      name = "enable_action_log_toggle_touch_fallback_never_crash_on_bad_cached_nodes",
      run = _test_enable_action_log_toggle_touch_fallback_never_crash_on_bad_cached_nodes,
    },
    {
      name = "enable_action_log_toggle_touch_prefers_named_ui_touch_path",
      run = _test_enable_action_log_toggle_touch_prefers_named_ui_touch_path,
    },
  },
}
