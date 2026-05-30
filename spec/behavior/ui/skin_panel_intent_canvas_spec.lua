local support = require("spec.support.shared_support")
local _with_patches = support.with_patches
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local view_command = require("src.ui.input.dispatch.view_command")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local ui_events = require("src.ui.coord.ui_events")
local skin_panel = require("src.ui.coord.skin_panel")

local function _no_op() end

local function _build_ui_state()
  return {
    set_visible = _no_op,
    set_label = _no_op,
    set_button = _no_op,
    set_touch_enabled = _no_op,
    market_active = false,
    choice_active = false,
    popup_active = false,
    move_active = false,
    query_node = function() return {} end,
  }
end

describe("skin_panel.open via view_command.dispatch", function()
  before_each(function()
    skin_panel.reset_for_tests()
  end)

  it("_test_open_skin_panel_intent_switches_canvas_for_resolved_role", function()
    local clicker_events = {}
    local other_events = {}
    local clicker = _build_role_with_events(1, clicker_events)
    local other = _build_role_with_events(2, other_events)
    local state = { ui = _build_ui_state(), ui_refs = { images = {} } }

    _with_patches({
      { target = runtime_ports, key = "resolve_role", value = function(role_id)
        if tostring(role_id) == "1" then return clicker end
        if tostring(role_id) == "2" then return other end
        return nil
      end },
      { target = ui_events, key = "roles", value = { clicker, other } },
    }, function()
      view_command.dispatch(state, { type = "open_skin_panel", actor_role_id = 1 })
    end)

    assert(state.ui.skin_panel and state.ui.skin_panel.open == true,
      "model state must mark skin panel open")
    assert(_has_event(clicker_events, "显示皮肤商店"),
      "clicker role must receive 显示皮肤商店 — model open without canvas show is the v102 bug")
    assert(not _has_event(other_events, "显示皮肤商店"),
      "non-clicker role must not have their canvas yanked to skin shop")
  end)

  it("_test_open_skin_panel_intent_broadcasts_when_actor_role_id_missing", function()
    local role1_events = {}
    local role2_events = {}
    local role1 = _build_role_with_events(1, role1_events)
    local role2 = _build_role_with_events(2, role2_events)
    local state = { ui = _build_ui_state(), ui_refs = { images = {} } }

    _with_patches({
      { target = runtime_ports, key = "resolve_role", value = function() return nil end },
      { target = ui_events, key = "roles", value = { role1, role2 } },
    }, function()
      view_command.dispatch(state, { type = "open_skin_panel" })
    end)

    assert(state.ui.skin_panel and state.ui.skin_panel.open == true,
      "model state must mark skin panel open even without actor_role_id")
    assert(_has_event(role1_events, "显示皮肤商店"),
      "broadcast path must reach role1 when actor_role_id is missing")
    assert(_has_event(role2_events, "显示皮肤商店"),
      "broadcast path must reach role2 when actor_role_id is missing")
  end)
end)
