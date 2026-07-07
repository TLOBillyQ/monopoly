-- luacheck: ignore 211
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local event_log_ports_module = require("src.ui.ports.event_log")
local runtime_port = require("src.ui.render.runtime_ui")
local ui_view = require("src.ui.coord.ui_runtime")
local ui_event_state = require("src.ui.coord.event_state")
local debug_flags = require("src.config.gameplay.debug_flags")

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

describe("presentation_ui.ports.event_log", function()
  it("_sync_enables_role_and_pushes_event_log_text", function()
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
      local ports = event_log_ports_module.build({ log_status = function() end })
      ports.sync_event_log(state)
    end)

    _assert_eq(state._debug_log_enabled_by_role[1], true, "enabled flag should be recorded for the role")
    _assert_eq(#visible_calls, 1, "visibility should toggle once on the enable transition")
    _assert_eq(visible_calls[1].enabled, true, "the role event log should become visible")
    _assert_eq(#text_calls, 1, "event log text should be pushed once")
    _assert_eq(text_calls[1].text, "第一行\n第二行", "pushed text should be the joined event log content")
  end)

  it("_sync_skips_redundant_updates_when_nothing_changed", function()
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
      local ports = event_log_ports_module.build({ log_status = function() end })
      ports.sync_event_log(state)
    end)

    _assert_eq(visible_count, 0, "no visibility toggle when the enabled state is unchanged")
    _assert_eq(text_count, 0, "no text push when the event log sequence is unchanged")
  end)

  it("_sync_pushes_empty_text_when_no_event_log_present", function()
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
      local ports = event_log_ports_module.build({ log_status = function() end })
      ports.sync_event_log(state)
    end)

    _assert_eq(#text_calls, 1, "content sync should still push text on the enable transition")
    _assert_eq(text_calls[1], "", "a missing event log should push an empty string, not nil")
  end)

  it("_sync_honours_configured_max_lines", function()
    -- Pins L43 `debug_flags.debug_log_max_lines or 50`: an `and` mutant ignores the configured
    -- limit and always uses 50.
    local role = { id = 1 }
    local text_calls = {}
    local log = {
      entries = { { text = "a" }, { text = "b" }, { text = "c" }, { text = "d" }, { text = "e" } },
      seq = 3,
    }
    local state = { game = { state = { event_log = log } } }

    _with_patches(_append(_runtime_patches(role), {
      { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return true end },
      { target = ui_view, key = "set_event_log_visible_for_role", value = function() end },
      { target = ui_view, key = "set_event_log_for_role", value = function(_, _r, text)
        text_calls[#text_calls + 1] = text
      end },
      { target = debug_flags, key = "debug_log_max_lines", value = 2 },
    }), function()
      local ports = event_log_ports_module.build({ log_status = function() end })
      ports.sync_event_log(state)
    end)

    _assert_eq(text_calls[1], "d\ne", "configured max_lines must bound the pushed text to the last 2 lines")
  end)

  it("_sync_initializes_role_maps_when_absent", function()
    -- Pins L77 / L78 `state.<map> or {}`: an `and` mutant leaves the map nil so nothing persists.
    local role = { id = 1 }
    local state = { game = { state = {} } }

    _with_patches(_append(_runtime_patches(role), {
      { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return true end },
      { target = ui_view, key = "set_event_log_visible_for_role", value = function() end },
      { target = ui_view, key = "set_event_log_for_role", value = function() end },
    }), function()
      local ports = event_log_ports_module.build({ log_status = function() end })
      ports.sync_event_log(state)
    end)

    assert(type(state._debug_log_enabled_by_role) == "table", "enabled-by-role map must be initialized")
    assert(type(state._debug_log_seq_by_role) == "table", "seq-by-role map must be initialized")
    _assert_eq(state._debug_log_enabled_by_role[1], true,
      "the enable transition must persist through the initialized map")
  end)

  it("_resolve_event_log_enabled_delegates_to_event_state", function()
    -- Pins L84 exposed `resolve_event_log_enabled`: a nil mutant drops the delegated result.
    local ports = event_log_ports_module.build({ log_status = function() end })
    local result

    _with_patches({
      { target = ui_event_state, key = "resolve_event_log_enabled", value = function(_, role_id)
        return role_id == 7
      end },
    }, function()
      result = ports.resolve_event_log_enabled({}, 7)
    end)

    _assert_eq(result, true, "the port must return the event-state resolution, not a constant")
  end)
end)
