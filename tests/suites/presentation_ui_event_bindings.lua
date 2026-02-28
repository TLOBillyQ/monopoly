local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local bindings = require("src.presentation.interaction.UIEventBindings")
local logger = require("src.core.Logger")
local runtime = require("src.presentation.api.UIRuntimePort")
local canvas_registry = require("src.presentation.canvas_runtime.CanvasRegistry")
local canvas_store = require("src.presentation.canvas_runtime.CanvasStore")
local base_nodes = require("src.presentation.canvas.base.nodes")
local always_show_nodes = require("src.presentation.canvas.always_show.nodes")

local function _find_spec(specs, node_name)
  for _, spec in ipairs(specs or {}) do
    if spec and spec.name == node_name then
      return spec
    end
  end
  return nil
end

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
    [always_show_nodes.action_log_button] = { _build_crash_node() },
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
  _assert_eq(calls[1].name, always_show_nodes.action_log_button, "touch should target action-log button")
  _assert_eq(calls[1].enabled, true, "toggle button should be enabled")
end

local function _test_canvas_registry_builds_canvas_first_route_specs()
  local state = {
    ui = {
      item_slots = { "基础_道具槽位1" },
      card_outlines = { "基础_可出牌外框1" },
      popup_screen = {
        dismiss_nodes = { "卡牌展示_图片" },
      },
      popup_active = true,
    },
    ui_model = {
      choice = {
        id = 10,
        kind = "item_phase_choice",
        options = { { id = 2001, label = "路障卡" } },
      },
    },
  }

  local specs = canvas_registry.build_route_specs(state)
  assert(_find_spec(specs, base_nodes.action_button) ~= nil, "route specs should include base action button")
  assert(_find_spec(specs, always_show_nodes.action_log_button) ~= nil, "route specs should include action log button")
  local outline_spec = _find_spec(specs, "基础_可出牌外框1")
  assert(outline_spec ~= nil, "route specs should include item outline node")
  local intent = outline_spec.build_intent and outline_spec.build_intent() or nil
  _assert_eq(intent and intent.id, "item_slot_1", "outline click should still map to item slot intent")
end

local function _test_canvas_store_patch_slice_marks_dirty()
  local state = {
    ui = {
      canvas_state = {},
    },
  }
  canvas_store.ensure(state)
  canvas_store.patch_slice(state, "choice", function(slice)
    slice.active = true
  end)

  local dirty = canvas_store.consume_dirty(state)
  _assert_eq(dirty.any, true, "canvas store should mark any dirty after patch")
  _assert_eq(dirty.choice, true, "canvas store should mark choice slice dirty after patch")
  _assert_eq(canvas_store.get_slice(state, "choice").active, true, "canvas store should persist patched value")

  local dirty_after_consume = canvas_store.consume_dirty(state)
  _assert_eq(dirty_after_consume.any, false, "canvas store consume should clear dirty flag")
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
    {
      name = "canvas_registry_builds_canvas_first_route_specs",
      run = _test_canvas_registry_builds_canvas_first_route_specs,
    },
    {
      name = "canvas_store_patch_slice_marks_dirty",
      run = _test_canvas_store_patch_slice_marks_dirty,
    },
  },
}
