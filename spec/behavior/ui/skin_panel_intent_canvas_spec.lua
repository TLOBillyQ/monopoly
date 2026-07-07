local support = require("spec.support.shared_support")
local _with_patches = support.with_patches
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local view_command = require("src.ui.input.view_command")
local presentation_ports = require("src.ui.ports")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local ui_events = require("src.ui.coord.ui_events")
local skin_panel = require("src.ui.coord.skin_panel")
local skin_intents = require("src.ui.input.route_skin_panel")
local skin_nodes = require("src.ui.schema.skin")

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
    local state = {
      ui = _build_ui_state(),
      ui_refs = { images = {} },
      gameplay_loop_ports = presentation_ports.build(),
    }

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
    local state = {
      ui = _build_ui_state(),
      ui_refs = { images = {} },
      gameplay_loop_ports = presentation_ports.build(),
    }

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

describe("skin_panel canvas action-button routing", function()
  local function _spec_named(specs, name)
    for _, spec in ipairs(specs) do
      if spec.name == name then
        return spec
      end
    end
    return nil
  end

  local function _state_with(selected)
    return {
      ui = {
        skin_panel = {
          role_id = 1,
          page_index = 1,
          owned_by_role = { ["1"] = { ["s1"] = true, ["s2"] = true } },
          selected_by_role = { ["1"] = selected },
        },
      },
    }
  end

  before_each(function()
    skin_panel.reset_for_tests()
    skin_panel.configure_catalog_for_tests({
      { product_id = "s1", name = "皮肤一" },
      { product_id = "s2", name = "皮肤二" },
    })
  end)

  after_each(function()
    skin_panel.reset_for_tests()
  end)

  it("_test_action_button_routes_activate_slot_for_equipped_slot", function()
    -- The input route should report the clicked slot. The transaction flow owns
    -- whether that activation equips or unequips.
    local state = _state_with("s1")
    local spec = _spec_named(skin_intents.build(state), skin_nodes.action_buttons[1])
    assert(spec ~= nil, "slot 1 action button must have a canvas route")
    local intent = spec.build_intent()
    assert(intent.type == "skin_panel_action", "route must dispatch a skin_panel_action intent")
    assert(intent.action.type == "activate_slot",
      "action button route should leave equip/unequip selection to the transaction flow")
    assert(intent.action.slot_index == 1, "activate_slot intent must carry the clicked slot index")
  end)

  it("_test_action_button_routes_activate_slot_for_unequipped_slot", function()
    local state = _state_with("s1")
    local spec = _spec_named(skin_intents.build(state), skin_nodes.action_buttons[2])
    assert(spec ~= nil, "slot 2 action button must have a canvas route")
    local intent = spec.build_intent()
    assert(intent.action.type == "activate_slot", "non-equipped slot's button should emit activate_slot")
    assert(intent.action.slot_index == 2, "activate_slot intent must carry the clicked slot index")
  end)

  it("_test_action_intent_does_not_read_live_equipped_state", function()
    local state = _state_with(nil)
    local specs = skin_intents.build(state)
    local spec = _spec_named(specs, skin_nodes.action_buttons[1])
    assert(spec ~= nil, "slot 1 action button must have a canvas route")
    assert(spec.build_intent().action.type == "activate_slot",
      "nothing equipped should still route through activate_slot")
    state.ui.skin_panel.selected_by_role["1"] = "s1"
    assert(spec.build_intent().action.type == "activate_slot",
      "equipped state changes should not alter the input-layer action")
  end)
end)
