-- luacheck: ignore 211
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local event_log_ports_module = require("src.ui.ports.event_log")
local runtime_port = require("src.ui.render.support.runtime_ui")
local ui_view = require("src.ui.coord.ui_runtime")
local ui_event_state = require("src.ui.coord.event_state")
local event_log_view = require("src.ui.coord.event_log_view")
local view_command = require("src.ui.ports.view_command")
local actor_context = require("src.ui.coord.actor_context")
local canvas = require("src.ui.coord.canvas_coordinator")
local logger = require("src.foundation.log")

local function _runtime_patches(role)
  return {
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn) fn(role) end },
    { target = runtime_port, key = "set_client_role", value = function() end },
    { target = runtime_port, key = "with_client_role", value = function(_, fn) fn() end },
    { target = runtime_port, key = "resolve_role_id", value = function(r) return r and r.id or nil end },
  }
end

local function _append(patches, extra)
  for _, patch in ipairs(extra) do
    patches[#patches + 1] = patch
  end
  return patches
end

TestEventLogPorts = {}

function TestEventLogPorts:test_sync_enables_role_and_pushes_event_log_text()
  -- Pins the enable transition + content push: L1 (event_log require), L13 get_text/or, L34
  -- get_seq, L41 `seq ~= stored`, L52 resolve, L53 `~=`, L62 normalize, L63 `role_id == nil`.
  local role = { id = 1 }
  local visible_calls = {}
  local text_calls = {}
  local log = { entries = { { text = "第一行" }, { text = "第二行" } }, seq = 9 }
  local state = { game = { state = { event_log = log } } }

  _with_patches(_append(_runtime_patches(role), {
    { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return true end },
    { target = ui_view, key = "set_event_log_visible_for_role", value = function(_, r, enabled)
      visible_calls[#visible_calls + 1] = { role = r, enabled = enabled }
    end },
    { target = ui_view, key = "set_event_log_for_role", value = function(_, r, text)
      text_calls[#text_calls + 1] = { role = r, text = text }
    end },
  }), function()
    local ports = event_log_ports_module.build()
    ports.sync_event_log(state)
  end)

  _assert_eq(state._debug_log_enabled_by_role[1], true, "enabled flag should be recorded for the role")
  _assert_eq(#visible_calls, 1, "visibility should toggle once on the enable transition")
  _assert_eq(visible_calls[1].enabled, true, "the role event log should become visible")
  _assert_eq(#text_calls, 1, "event log text should be pushed once")
  _assert_eq(text_calls[1].text, "第一行\n第二行", "pushed text should be the joined event log content")
end

function TestEventLogPorts:test_sync_skips_redundant_updates_when_nothing_changed()
  -- Pins the no-op paths: L36 `return 0`, L40 `_read_current_seq`, L41 `read(...)`, L53 `read(...)`.
  local role = { id = 1 }
  local visible_count = 0
  local text_count = 0
  local state = {
    _debug_log_enabled_by_role = { [1] = true },
    _debug_log_seq_by_role = { [1] = 0 },
    game = { state = {} },
  }

  _with_patches(_append(_runtime_patches(role), {
    { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return true end },
    { target = ui_view, key = "set_event_log_visible_for_role", value = function() visible_count = visible_count + 1 end },
    { target = ui_view, key = "set_event_log_for_role", value = function() text_count = text_count + 1 end },
  }), function()
    local ports = event_log_ports_module.build()
    ports.sync_event_log(state)
  end)

  _assert_eq(visible_count, 0, "no visibility toggle when the enabled state is unchanged")
  _assert_eq(text_count, 0, "no text push when the event log sequence is unchanged")
end

function TestEventLogPorts:test_sync_pushes_empty_text_when_no_event_log_present()
  -- Pins L15 `_resolve_event_text` fallback `return ""`: a `return nil` mutant pushes nil.
  local role = { id = 1 }
  local text_calls = {}
  local state = { game = { state = {} } }

  _with_patches(_append(_runtime_patches(role), {
    { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return true end },
    { target = ui_view, key = "set_event_log_visible_for_role", value = function() end },
    { target = ui_view, key = "set_event_log_for_role", value = function(_, _r, text)
      text_calls[#text_calls + 1] = text
    end },
  }), function()
    local ports = event_log_ports_module.build()
    ports.sync_event_log(state)
  end)

  _assert_eq(#text_calls, 1, "content sync should still push text on the enable transition")
  _assert_eq(text_calls[1], "", "a missing event log should push an empty string, not nil")
end

function TestEventLogPorts:test_sync_pushes_the_complete_retained_event_log()
  local role = { id = 1 }
  local text_calls = {}
  local log = {
    entries = { { text = "a" }, { text = "b" }, { text = "c" }, { text = "d" }, { text = "e" } },
    seq = 5,
  }
  local state = { game = { state = { event_log = log } } }

  _with_patches(_append(_runtime_patches(role), {
    { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return true end },
    { target = ui_view, key = "set_event_log_visible_for_role", value = function() end },
    { target = ui_view, key = "set_event_log_for_role", value = function(_, _r, text)
      text_calls[#text_calls + 1] = text
    end },
  }), function()
    local ports = event_log_ports_module.build()
    ports.sync_event_log(state)
  end)

  _assert_eq(text_calls[1], "a\nb\nc\nd\ne", "the UI must show the complete retained event log")
end

function TestEventLogPorts:test_sync_pushes_the_latest_display_window_after_the_log_overflows()
  local role = { id = 1 }
  local text_calls = {}
  local entries = {}
  for index = 1, 60 do
    entries[index] = { text = "行动" .. tostring(index) }
  end
  local state = {
    game = {
      state = {
        event_log = { entries = entries, seq = 60 },
      },
    },
  }

  _with_patches(_append(_runtime_patches(role), {
    { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return true end },
    { target = ui_view, key = "set_event_log_visible_for_role", value = function() end },
    { target = ui_view, key = "set_event_log_for_role", value = function(_, _r, text)
      text_calls[#text_calls + 1] = text
    end },
  }), function()
    local ports = event_log_ports_module.build()
    ports.sync_event_log(state)
  end)

  _assert_eq(text_calls[1]:match("^行动41"), "行动41", "the first visible line should move forward after overflow")
  lu.assertNotNil(text_calls[1]:match("行动60$"), "the newest action should remain visible at the bottom")
  lu.assertNil(text_calls[1]:match("行动40"), "the entry just outside the display window should not pin the viewport")
end

function TestEventLogPorts:test_sync_display_window_boundary_at_exact_limit()
  -- Pins DISPLAY_LINE_LIMIT = 20：恰好 20 条全量上屏，第 21 条把窗口整体后移一格。
  local function _push_with_entries(count)
    local role = { id = 1 }
    local text_calls = {}
    local entries = {}
    for index = 1, count do
      entries[index] = { text = "行动" .. tostring(index) }
    end
    local state = { game = { state = { event_log = { entries = entries, seq = count } } } }
    _with_patches(_append(_runtime_patches(role), {
      { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return true end },
      { target = ui_view, key = "set_event_log_visible_for_role", value = function() end },
      { target = ui_view, key = "set_event_log_for_role", value = function(_, _r, text)
        text_calls[#text_calls + 1] = text
      end },
    }), function()
      event_log_ports_module.build().sync_event_log(state)
    end)
    return text_calls[1]
  end

  local at_limit = _push_with_entries(20)
  _assert_eq(at_limit:match("^行动1\n"), "行动1\n", "exactly 20 entries should all stay visible")
  lu.assertNotNil(at_limit:match("行动20$"), "the 20th entry should be the last visible line")

  local over_limit = _push_with_entries(21)
  _assert_eq(over_limit:match("^行动2\n"), "行动2\n", "the 21st entry should slide the window past the first line")
  lu.assertNotNil(over_limit:match("行动21$"), "the newest entry should remain at the bottom")
end

function TestEventLogPorts:test_sync_initializes_role_maps_when_absent()
  -- Pins L77 / L78 `state.<map> or {}`: an `and` mutant leaves the map nil so nothing persists.
  local role = { id = 1 }
  local state = { game = { state = {} } }

  _with_patches(_append(_runtime_patches(role), {
    { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return true end },
    { target = ui_view, key = "set_event_log_visible_for_role", value = function() end },
    { target = ui_view, key = "set_event_log_for_role", value = function() end },
  }), function()
    local ports = event_log_ports_module.build()
    ports.sync_event_log(state)
  end)

  lu.assertEvalToTrue(type(state._debug_log_enabled_by_role) == "table", "enabled-by-role map must be initialized")
  lu.assertEvalToTrue(type(state._debug_log_seq_by_role) == "table", "seq-by-role map must be initialized")
  _assert_eq(state._debug_log_enabled_by_role[1], true,
    "the enable transition must persist through the initialized map")
end

function TestEventLogPorts:test_sync_pushes_empty_text_on_the_disable_transition_262()
  -- kills _apply_enabled_change 关闭臂 set_event_log_for_role(state, role, "")
  -- 的 "" -> nil:关闭时必须用空串清内容,不是 nil。
  local role = { id = 1 }
  local text_calls = {}
  local visible_calls = {}
  local state = {
    _debug_log_enabled_by_role = { [1] = true },
    _debug_log_seq_by_role = { [1] = 3 },
    game = { state = {} },
  }

  _with_patches(_append(_runtime_patches(role), {
    { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return false end },
    { target = ui_view, key = "set_event_log_visible_for_role", value = function(_, _, enabled)
      visible_calls[#visible_calls + 1] = enabled
    end },
    { target = ui_view, key = "set_event_log_for_role", value = function(_, _, text)
      text_calls[#text_calls + 1] = text
    end },
  }), function()
    local ports = event_log_ports_module.build()
    ports.sync_event_log(state)
  end)

  _assert_eq(state._debug_log_enabled_by_role[1], false, "the disable transition must be recorded")
  _assert_eq(visible_calls[1], false, "the role event log should become invisible")
  _assert_eq(#text_calls, 1, "the disable transition should clear the content once")
  _assert_eq(text_calls[1], "", "the disable transition must clear content with an empty string, not nil")
end

function TestEventLogPorts:test_resolve_event_log_enabled_delegates_to_event_state()
  -- Pins L84 exposed `resolve_event_log_enabled`: a nil mutant drops the delegated result.
  local ports = event_log_ports_module.build()
  local result

  _with_patches({
    { target = ui_event_state, key = "resolve_event_log_enabled", value = function(_, role_id)
      return role_id == 7
    end },
  }, function()
    result = ports.resolve_event_log_enabled({}, 7)
  end)

  _assert_eq(result, true, "the port must return the event-state resolution, not a constant")
end

function TestEventLogPorts:test_toggle_action_log_syncs_current_content_when_opening()
  local warnings = {}
  local text_calls = {}
  local role = { id = 9 }
  local state = {
    ui = {
      debug_log_enabled_by_role = {},
      set_event_log_visible = function(_, visible)
        _assert_eq(visible, true, "toggle should enable hidden action log")
      end,
      set_event_log = function(_, text)
        text_calls[#text_calls + 1] = text
      end,
    },
    game = {
      state = {
        event_log = { entries = { { text = "已有结果" } }, seq = 1 },
      },
    },
  }
  local debug = event_log_ports_module.build()
  local ports = view_command.build({ sync_event_log = debug.sync_event_log })

  _with_patches(_append(_runtime_patches(role), {
    { target = actor_context, key = "resolve_role_by_id", value = function() return role end },
    { target = canvas, key = "switch_for_role", value = function() end },
    { target = logger, key = "warn", value = function(...)
      warnings[#warnings + 1] = table.concat({ ... }, " ")
    end },
  }), function()
    _assert_eq(ports.dispatch(state, { type = "toggle_action_log", actor_role_id = 9 }), true,
      "toggle action log command should be handled")
  end)

  lu.assertEvalToTrue((warnings[1] or ""):find("toggle_action_log missing role event channel", 1, true),
    "toggle should warn when active role cannot receive UI events")
  _assert_eq(text_calls[1], "已有结果", "opening the action log should push its current content")
end

function TestEventLogPorts:test_resolve_event_log_enabled_resolves_explicit_and_current_role_flags()
  local role = { id = "role-a" }
  local state = {
    ui = {
      debug_log_enabled_by_role = {
        ["role-a"] = true,
        ["9"] = false,
      },
    },
  }

  _with_patches({
    { target = runtime_port, key = "get_client_role", value = function()
      return role
    end },
    { target = runtime_port, key = "resolve_role_id", value = function(value)
      return value and value.id or nil
    end },
  }, function()
    _assert_eq(ui_event_state.resolve_event_log_enabled(state, nil), true,
      "nil role should resolve current client role")
    _assert_eq(ui_event_state.resolve_event_log_enabled(state, 9), false,
      "explicit role should read by normalized id")
    _assert_eq(ui_event_state.resolve_event_log_enabled(state, nil), true,
      "current role should remain enabled")
  end)
end

function TestEventLogPorts:test_resolve_event_log_enabled_returns_false_when_role_unresolvable_or_flag_map_missing_262()
  -- kills 两个 false->true:role_id 解析不出时短路 false,以及
  -- debug_log_enabled_by_role 不是 table 时读 false。
  _assert_eq(ui_event_state.resolve_event_log_enabled({ ui = {} }, 7), false,
    "missing flag map must read as disabled")
  _with_patches({
    { target = runtime_port, key = "get_client_role", value = function()
      return nil
    end },
    { target = runtime_port, key = "resolve_role_id", value = function()
      return nil
    end },
  }, function()
    _assert_eq(ui_event_state.resolve_event_log_enabled({ ui = {} }, nil), false,
      "unresolvable role must read as disabled")
  end)
end

function TestEventLogPorts:test_open_close_is_open_guard_ui_role_id_and_record_visibility()
  local recorded = {}
  local ui = { set_event_log_visible = function(_, value) recorded[#recorded + 1] = value end }
  local state = { ui = ui }

  -- open: records role visibility and drives the host setter to true.
  _assert_eq(event_log_view.open(state, 7), true, "open should record and return true")
  _assert_eq(recorded[1], true, "open should drive the host visibility setter to true")
  _assert_eq(event_log_view.is_open(state, 7), true, "an opened role reads back as open")

  -- close: records false; the role no longer reads as open.
  _assert_eq(event_log_view.close(state, 7), true, "close should record and return true")
  _assert_eq(recorded[2], false, "close should drive the host visibility setter to false")
  _assert_eq(event_log_view.is_open(state, 7), false, "a closed role reads back as not open")

  -- guards: missing state/ui and an un-normalizable role id all short-circuit.
  _assert_eq(event_log_view.open(nil, 7), false, "nil state cannot open")
  _assert_eq(event_log_view.open({}, 7), false, "state without ui cannot open")
  _assert_eq(event_log_view.open(state, nil), false, "an un-normalizable role id cannot open")

  -- ui without the host setter still records visibility and returns true.
  local bare_state = { ui = {} }
  _assert_eq(event_log_view.open(bare_state, 3), true, "open should succeed without a host setter")
  _assert_eq(event_log_view.is_open(bare_state, 3), true, "recorded role reads as open without a setter")

  -- is_open guards a missing visibility table.
  _assert_eq(event_log_view.is_open({ ui = {} }, 9), false, "no visibility table reads as not open")
end


return TestEventLogPorts
